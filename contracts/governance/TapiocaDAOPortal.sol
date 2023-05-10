// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "tapioca-sdk/dist/contracts/util/ERC4494.sol";
import "../tokens/TapOFT.sol";
import "../twAML.sol";

// ********************************************************************************
// *******************************,                 ,******************************
// *************************                               ************************
// *********************                                       ********************
// *****************,                     @@@                     ,****************
// ***************                        @@@                        **************
// *************                    (@@@@@@@@@@@@@(                    ************
// ***********                   @@@@@@@@#@@@#@@@@@@@@                   **********
// **********                 .@@@@@      @@@      @@@@@.                 *********
// *********                 @@@@@        @@@        @@@@@                 ********
// ********                 @@@@@&        @@@         /@@@@                 *******
// *******                 &@@@@@@        @@@          #@@@&                 ******
// ******,                 @@@@@@@@,      @@@           @@@@                 ,*****
// ******                 #@@@&@@@@@@@@#  @@@           &@@@(                 *****
// ******                 %@@@%   @@@@@@@@@@@@@@@(      (@@@%                 *****
// ******                 %@@@%          %@@@@@@@@@@@@. %@@@#                 *****
// ******.                /@@@@           @@@    *@@@@@@@@@@*                .*****
// *******                 @@@@           @@@       &@@@@@@@                 ******
// *******                 /@@@@          @@@        @@@@@@/                .******
// ********                 %&&&&         @@@        &&&&&#                 *******
// *********                 *&&&&#       @@@       &&&&&,                 ********
// **********.                 %&&&&&,    &&&    ,&&&&&%                 .*********
// ************                   &&&&&&&&&&&&&&&&&&&                   ***********
// **************                     .#&&&&&&&%.                     *************
// ****************                       %%%                       ***************
// *******************                    %%%                    ******************
// **********************                                    .*********************
// ***************************                           **************************
// ************************************..     ..***********************************

// TODO: Compact data sizes? Leave out Magnitude? Struct-in-struct?
struct Participation {
    bool hasVotingPower;
    bool divergenceForce; // 0 negative, 1 positive
    uint256 averageMagnitude;
    uint256 expiry; // expiry timestamp
    uint256 tapAmount; // amount of TAP locked
    uint256 votes; // voting power. tapAmount (while locked) * multiplier
    uint256 lastInactive; // One week BEFORE the staker gets a share of rewards
    uint256 lastActive; // Last week that the staker shares in rewards
}

struct TWAMLPool {
    uint256 totalParticipants;
    uint256 averageMagnitude;
    uint256 totalDeposited;
    uint256 cumulative;
}

struct WeekTotals {
    // For [0..currentWeek] this is a cumulative total: it consists of the
    // active votes in the previous week, minus the votes known to expire this
    // week. For future weeks, it is a negative number corresponding to the
    // expiring votes.
    // TODO: Will fit in an int128
    int256 netActiveVotes;
    // rewardTokens index -> amount
    mapping(uint256 => uint256) totalDistPerVote;
}

contract TapiocaDAOPortal is
    BoringOwnable,
    TWAML,
    ERC721,
    ERC721Permit,
    BaseBoringBatchable
{
    using SafeERC20 for IERC20;

    TapOFT public immutable tapOFT;

    /// ===== TWAML ======
    TWAMLPool public twAML; // sglAssetId => twAMLPool

    mapping(uint256 => Participation) public participants; // tokenId => part.

    uint256 constant MIN_WEIGHT_FACTOR = 10; // In BPS, 0.1%
    uint256 constant dMAX = 100 * 1e4; // 10% - 100% voting power multiplier
    uint256 constant dMIN = 10 * 1e4;
    uint256 constant WEEK = 7 days;

    // If we assume 128 bit balances for the reward token -- which fit 1e40
    // "tokens" at the most comonly used 1e18 precision -- then we can use
    // the other 128 bits to store the tokens allotted to a single vote more
    // accurately. Votes are proportional to the amount of TAP locked, weighted
    // by a multiplier. TAP has a supply of 100M * 1e18 (87 bits), and the
    // weight ranges from 10-100% in basis points, so 10k (14 bits).
    // the multiplier is at most 100% = 10k (14 bits), so we are safe.
    uint256 constant DIST_PRECISION = 2 ** 128;

    // The current week is determined by creation, but there are values that
    // need to be updated weekly. If, for any reason whatsoever, this cannot
    // be done in time, the `lastProcessedWeek` will be behind until this is
    // done.

    IERC20[] public rewardTokens;
    // tokenId -> rewardTokens index -> amount
    mapping(uint256 => mapping(uint256 => uint256)) public claimed;

    uint256 public mintedTWTap;
    uint256 public creation; // Week 0 starts here
    uint256 public lastProcessedWeek;
    mapping(uint256 => WeekTotals) public weekTotals;

    /// =====-------======
    constructor(
        address _tapOFT,
        address _owner
    ) ERC721("Time Weighted TAP", "twTAP") ERC721Permit("Time Weighted TAP") {
        tapOFT = TapOFT(_tapOFT);
        owner = _owner;
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(
        address indexed participant,
        uint256 tapAmount,
        uint256 multiplier
    );
    event AMLDivergence(
        uint256 cumulative,
        uint256 averageMagnitude,
        uint256 totalParticipants
    );
    event ExitPosition(uint256 tokenId, uint256 amount);

    // ==========
    //    READ
    // ==========

    function currentWeek() public view returns (uint256) {
        return (block.timestamp - creation) / WEEK;
    }

    /// @notice Amount currently claimable for each reward token
    function claimable(
        uint256 _tokenId
    ) public view returns (uint256[] memory) {
        uint256 len = rewardTokens.length;
        uint256[] memory result = new uint256[](len);

        // Why not storage? Because we are going to fit it all into one slot
        Participation memory position = participants[_tokenId];
        // Math is safe: (TODO: update types)
        uint256 votes = position.votes;
        if (votes == 0) {
            return result;
        }

        // If the "last processed week" is behind the actual week, rewards
        // get processed as if it were earlier.
        uint256 week = lastProcessedWeek;
        if (week <= position.lastInactive) {
            return result;
        }
        if (position.lastActive < week) {
            week = position.lastActive;
        }

        WeekTotals storage cur = weekTotals[week];
        WeekTotals storage prev = weekTotals[position.lastInactive];

        for (uint256 i = 0; i < len; ) {
            // Math is safe: (TODO: proof, make entire loop unchecked)
            uint256 net = cur.totalDistPerVote[i] - prev.totalDistPerVote[i];
            result[i] = ((votes * net) / DIST_PRECISION) - claimed[_tokenId][i];
            unchecked {
                ++i;
            }
        }
        return result;
    }

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in twAMl voting and mint an oTAP position
    /// @param _participant The address of the participant
    /// @param _amount The amount of TAP to participate with
    /// @param _duration The duration of the lock
    function participate(
        address _participant,
        uint256 _amount,
        uint256 _duration
    ) external returns (uint256 tokenId) {
        require(_duration >= WEEK, "TapiocaDAOPortal: Lock not a week");

        // Transfer TAP to this contract
        tapOFT.transferFrom(msg.sender, address(this), _amount);

        // Copy to memory
        TWAMLPool memory pool = twAML;

        uint256 magnitude = computeMagnitude(_duration, pool.cumulative);
        bool divergenceForce;
        uint256 multiplier = computeTarget(
            dMIN,
            dMAX,
            magnitude,
            pool.cumulative
        );

        // Calculate twAML voting weight
        bool hasVotingPower = _amount >=
            computeMinWeight(pool.totalDeposited, MIN_WEIGHT_FACTOR);
        if (hasVotingPower) {
            pool.totalParticipants++; // Save participation
            pool.averageMagnitude =
                (pool.averageMagnitude + magnitude) /
                pool.totalParticipants; // compute new average magnitude

            // Compute and save new cumulative
            divergenceForce = _duration > pool.cumulative;
            if (divergenceForce) {
                if (pool.cumulative > pool.averageMagnitude) {
                    pool.cumulative -= pool.averageMagnitude;
                } else {
                    pool.cumulative = 0;
                }
            } else {
                pool.cumulative += pool.averageMagnitude;
            }

            // Save new weight
            pool.totalDeposited += _amount;

            twAML = pool; // Save twAML participation
            emit AMLDivergence(
                pool.cumulative,
                pool.averageMagnitude,
                pool.totalParticipants
            );
        }

        // Mint twTAP position
        tokenId = ++mintedTWTap;
        _safeMint(_participant, tokenId);

        uint256 expiry = block.timestamp + _duration;
        // Cast is safe: votes fits in 87 + 14 bits
        // TODO: Update / encode
        // Eligibility starts NEXT week (for the locker; not globally)
        uint256 w0 = currentWeek();
        uint256 w1 = w0 + (expiry - creation) / WEEK;

        // Save twAML participation
        uint256 votes = _amount * multiplier;
        participants[tokenId] = Participation({
            hasVotingPower: hasVotingPower,
            divergenceForce: divergenceForce,
            averageMagnitude: pool.averageMagnitude,
            expiry: expiry,
            tapAmount: _amount,
            votes: votes,
            lastInactive: w0,
            lastActive: w1
        });

        // Cast is safe: votes fits in 87 + 14 bits
        //   `multiplier` fits in 14 bits (TODO: Enforce -- merge)
        //   `tapAmount` fits in 87 bits (see TAP contract)
        weekTotals[w0].netActiveVotes += int256(votes);
        weekTotals[w1].netActiveVotes -= int256(votes);

        emit Participate(_participant, _amount, multiplier);
        // TODO: Mint event?
    }

    /// @notice claims all rewards distributed since token mint or last claim.
    /// @param _tokenId tokenId whose rewards to claim
    /// @param _to address to receive the rewards
    function claimRewards(uint256 _tokenId, address _to) external {
        _requireClaimPermission(_to, _tokenId);
        _claimRewards(_tokenId, _to);
    }

    /// @notice claims the TAP locked in a position whose votes have expired,
    /// @notice and undoes the effect on the twAML calculations.
    /// @param _tokenId tokenId whose locked TAP to claim
    /// @param _to address to receive the TAP
    function releaseTap(uint256 _tokenId, address _to) external {
        _requireClaimPermission(_to, _tokenId);
        _releaseTap(_tokenId, _to);
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    /// @param _tokenId The tokenId of the twTAP position
    function exitPosition(uint256 _tokenId) external {
        _releaseTap(_tokenId, ownerOf(_tokenId));
    }

    /// @notice Indicate that (a) week(s) have passed and update running totals
    /// @notice Reverts if called in week 0. Let it.
    /// @param _limit Maximum number of weeks to process in one call
    function advanceWeek(uint256 _limit) public {
        // TODO: Make whole function unchecked
        uint256 cur = currentWeek();
        uint256 week = lastProcessedWeek;
        uint256 goal = cur;
        unchecked {
            if (goal - week > _limit) {
                goal = week + _limit;
            }
        }
        uint256 len = rewardTokens.length;
        while (week < goal) {
            WeekTotals storage prev = weekTotals[week];
            WeekTotals storage next = weekTotals[++week];
            // TODO: Math is safe
            next.netActiveVotes += prev.netActiveVotes;
            for (uint256 i = 0; i < len; ) {
                next.totalDistPerVote[i] += prev.totalDistPerVote[i];
                unchecked {
                    ++i;
                }
            }
        }
        lastProcessedWeek = goal;
    }

    /// @notice distributes a reward among all tokens, weighted by voting power
    /// @notice The reward gets allocated to all positions that have locked in
    /// @notice the current week. Fails, intentionally, if this number is zero.
    /// @param _rewardTokenId index of the reward in `rewardTokens`
    /// @param _amount amount of reward token to distribute
    function distributeReward(
        uint256 _rewardTokenId,
        uint256 _amount
    ) external {
        require(lastProcessedWeek == currentWeek(), "Week not updated");
        WeekTotals storage totals = weekTotals[lastProcessedWeek];
        IERC20 rewardToken = rewardTokens[_rewardTokenId];
        // If this is a DBZ then there are no positions to give the reward to.
        // Since reward eligibility starts in the week after locking, there is
        // no way to give out rewards THIS week:
        // Cast is safe: `netActiveVotes` is at most zero by construction of
        // weekly totals and the requirement that they are up to date.
        // TODO: Word this better
        totals.totalDistPerVote[_rewardTokenId] +=
            (_amount * DIST_PRECISION) /
            uint256(totals.netActiveVotes);
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    // =========
    //   OWNER
    // =========

    function addRewardToken(IERC20 token) external onlyOwner returns (uint256) {
        uint256 i = rewardTokens.length;
        rewardTokens.push(token);
        return i;
    }

    // ============
    //   INTERNAL
    // ============

    // Mirrors the implementation of _isApprovedOrOwner, with the modification
    // that it is allowed if `_to` is the owner:
    function _requireClaimPermission(
        address _to,
        uint256 _tokenId
    ) internal view {
        address owner = ownerOf(_tokenId);
        require(
            msg.sender == owner ||
                _to == owner ||
                isApprovedForAll(owner, msg.sender) ||
                getApproved(_tokenId) == msg.sender,
            "TapiocaDAOPortal: cannot claim"
        );
    }

    function _claimRewards(uint256 _tokenId, address _to) internal {
        uint256[] memory amounts = claimable(_tokenId);
        uint256 len = amounts.length;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                uint256 amount = amounts[i];
                if (amount > 0) {
                    // Math is safe: `amount` calculated safely in `claimable()`
                    claimed[_tokenId][i] += amount;
                    rewardTokens[i].safeTransfer(_to, amount);
                }
            }
        }
    }

    function _releaseTap(uint256 _tokenId, address _to) internal {
        Participation storage position = participants[_tokenId];
        require(
            position.expiry <= block.timestamp,
            "TapiocaDAOPortal: Lock not expired"
        );

        uint256 amount = position.tapAmount;
        if (amount == 0) {
            return;
        }
        tapOFT.transfer(_to, amount);

        // Remove participation
        if (position.hasVotingPower) {
            TWAMLPool memory pool = twAML;

            pool.cumulative = position.divergenceForce
                ? pool.cumulative - position.averageMagnitude
                : pool.cumulative + position.averageMagnitude;
            pool.totalDeposited -= position.tapAmount;
            pool.totalParticipants--;

            twAML = pool; // Save twAML exit
            emit AMLDivergence(
                pool.cumulative,
                pool.averageMagnitude,
                pool.totalParticipants
            ); // Register new voting power event
        }
        position.tapAmount = 0;

        emit ExitPosition(_tokenId, amount);
    }
}
