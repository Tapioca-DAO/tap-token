// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {ICommonOFT} from "tapioca-sdk/dist/contracts/token/oft/v2/ICommonOFT.sol";
import {ONFT721} from "tapioca-sdk/src/contracts/token/onft/ONFT721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

// Justification for data sizes:
// - 56 bits can represent over 2 billion years in seconds
// - TAP has a maximum supply of 100 million, and a precision of 10^18. Any
//   amount will therefore fit in (lg 10^26 = 87) bits.
// - The multiplier has a maximum of 1 million; dMAX = 100 * 1e4, which fits
//   in 20 bits.
// - A week is 86400 * 7 = 604800 seconds; less than 2^20. Even if we start
//   counting at the (Unix) epoch, we will run out of `expiry` before we
//   saturate the week fields.
struct Participation {
    uint256 averageMagnitude;
    bool hasVotingPower;
    bool divergenceForce; // 0 negative, 1 positive
    bool tapReleased; // allow restaking while rewards may still accumulate
    uint56 expiry; // expiry timestamp. Big enough for over 2 billion years..
    uint88 tapAmount; // amount of TAP locked
    uint24 multiplier; // Votes = multiplier * tapAmount
    uint40 lastInactive; // One week BEFORE the staker gets a share of rewards
    uint40 lastActive; // Last week that the staker shares in rewards
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
    int256 netActiveVotes;
    // rewardTokens index -> amount
    mapping(uint256 => uint256) totalDistPerVote;
}

contract TwTAP is TWAML, ONFT721, ERC721Permit, ReentrancyGuard {
    using SafeERC20 for IERC20;

    TapOFT public immutable tapOFT;

    /// ===== TWAML ======
    TWAMLPool public twAML; // sglAssetId => twAMLPool

    mapping(uint256 => Participation) public participants; // tokenId => part.

    uint256 constant MIN_WEIGHT_FACTOR = 10; // In BPS, 0.1%
    uint256 constant dMAX = 100 * 1e4; // 10% - 100% voting power multiplier
    uint256 constant dMIN = 10 * 1e4;
    uint256 public constant EPOCH_DURATION = 7 days;

    // If we assume 128 bit balances for the reward token -- which fit 1e40
    // "tokens" at the most commonly used 1e18 precision -- then we can use the
    // other 128 bits to store the tokens allotted to a single vote more
    // accurately. Votes in turn are proportional to the amount of TAP locked,
    // weighted by a multiplier. This number is at most 107 bits long (see
    // definition of `Participation` struct).
    // the weight ranges from 10-100% where 1% = 1e4, so 1 million (20 bits).
    // the multiplier is at most 100% = 1M (20 bits), so votes is at most a
    // 107-bit number.
    uint256 constant DIST_PRECISION = 2 ** 128;

    IERC20[] public rewardTokens;
    mapping(IERC20 => uint256) public rewardTokenIndex;
    uint256 public maxRewardTokens;

    // tokenId -> rewardTokens index -> amount
    mapping(uint256 => mapping(uint256 => uint256)) public claimed;

    // The current week is determined by creation, but there are values that
    // need to be updated weekly. If, for any reason whatsoever, this cannot
    // be done in time, the `lastProcessedWeek` will be behind until this is
    // done.
    uint256 public mintedTWTap;
    uint256 public creation; // Week 0 starts here
    uint256 public lastProcessedWeek;
    mapping(uint256 => WeekTotals) public weekTotals;

    uint256 public immutable HOST_CHAIN_ID;
    string private baseURI;

    event LogMaxRewardsLength(
        uint256 _oldLength,
        uint256 _newLength,
        uint256 _currentLength
    );

    /// =====-------======
    constructor(
        address payable _tapOFT,
        address _owner,
        address _layerZeroEndpoint,
        uint256 _hostChainID,
        uint256 _minGas
    )
        ONFT721("Time Weighted TAP", "twTAP", _minGas, _layerZeroEndpoint)
        ERC721Permit("Time Weighted TAP")
    {
        tapOFT = TapOFT(_tapOFT);
        transferOwnership(_owner);
        creation = block.timestamp;
        HOST_CHAIN_ID = _hostChainID;

        maxRewardTokens = 1000;
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
    event ExitPosition(uint256 indexed tokenId, uint256 amount);

    // ==========
    //    READ
    // ==========

    function currentWeek() public view returns (uint256) {
        return (block.timestamp - creation) / EPOCH_DURATION;
    }

    /// @notice Return the participation of a token. Returns 0 votes for expired tokens.
    function getParticipation(
        uint _tokenId
    ) public view returns (Participation memory participant) {
        participant = participants[_tokenId];
        if (participant.expiry <= block.timestamp) {
            participant.multiplier = 0;
        }
        return participant;
    }

    /// @notice Amount currently claimable for each reward token
    function claimable(
        uint256 _tokenId
    ) public view returns (uint256[] memory) {
        uint256 len = rewardTokens.length;
        uint256[] memory result = new uint256[](len);

        Participation memory position = participants[_tokenId];
        uint256 votes;
        unchecked {
            // Math is safe: Types fit
            votes = uint256(position.tapAmount) * uint256(position.multiplier);
        }

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
            // Math is safe (but we do the checks anyway):
            //
            // -- The `totalDistPerVote[i]` values are increasing as a
            //    function of weeks (see `advanceWeek()`), and if `week`
            //    were not greater than `position.lastInactive`, this bit
            //    of code would not be reached (see above). Therefore the
            //    subtraction in the calculation of `net` cannot underflow.
            //
            // -- `votes * net` is at most the entire reward amount given
            //    out, ever, in units of
            //
            //        (reward tokens) * DIST_PRECISION.
            //
            //    If this number were to exceed 256 bits, then
            //    `distributeReward` would revert.
            //
            // -- `claimed[_tokenId][i]` is the sum of all (the i-th values
            //    of) previous calls to the current function that were made
            //    by `_claimRewards()`. Let there be n such calls, and let
            //    r_j be `result[i]`, c_j be `claimed[_tokenId][i]`, and
            //    net_j be `net` during that j-th call. Then, up to a
            //    multiplication by votes / DIST_PRECISION:
            //
            //              c_1 = 0 <= net_1,
            //
            //    and, for n > 1:
            //
            //              c_n = r_(n-1) + r_(n-2) + ... + r_1
            //                  = r_(n-1) + c_(n-1)
            //                  = (net_(n-1) - c_(n-1) + c_(n-1)
            //                  = net_(n-1)
            //                  <= net_n,
            //
            //    so that the subtraction net_n - c_n does not underflow.
            //    (The rounding the calculation favors the greater first
            //    term).
            //    (TODO: Word better?)
            //
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
    ) external nonReentrant returns (uint256 tokenId) {
        require(_duration >= EPOCH_DURATION, "twTAP: Lock not a week");

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
                pool.cumulative += pool.averageMagnitude;
            } else {
                // TODO: Strongly suspect this is never less. Prove it.
                if (pool.cumulative > pool.averageMagnitude) {
                    pool.cumulative -= pool.averageMagnitude;
                } else {
                    pool.cumulative = 0;
                }
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
        require(expiry < type(uint56).max, "twTAP: too long");
        // Eligibility starts NEXT week, and lasts until the week that the lock
        // expires. This is guaranteed to be at least one week later by the
        // check on `_duration`.
        // If a user locks right before the current week ends, and have a
        // duration slightly over one week, straddling the two starting points,
        // then that user is eligible for the rewards during both weeks; the
        // price for this maneuver is a lower multiplier, and loss of voting
        // power in the DAO after the lock expires.
        uint256 w0 = currentWeek();
        uint256 w1 = (expiry - creation) / EPOCH_DURATION;

        // Save twAML participation
        // Casts are safe: see struct definition
        uint256 votes = _amount * multiplier;
        participants[tokenId] = Participation({
            averageMagnitude: pool.averageMagnitude,
            hasVotingPower: hasVotingPower,
            divergenceForce: divergenceForce,
            tapReleased: false,
            expiry: uint56(expiry),
            tapAmount: uint88(_amount),
            multiplier: uint24(multiplier),
            lastInactive: uint40(w0),
            lastActive: uint40(w1)
        });

        // w0 + 1 = lastInactive + 1 = first active
        // w1 + 1 = lastActive + 1 = first inactive
        // Cast is safe: `votes` is the product of a uint88 and a uint24
        weekTotals[w0 + 1].netActiveVotes += int256(votes);
        weekTotals[w1 + 1].netActiveVotes -= int256(votes);

        emit Participate(_participant, _amount, multiplier);
        // TODO: Mint event?
    }

    /// @notice claims all rewards distributed since token mint or last claim.
    /// @param _tokenId tokenId whose rewards to claim
    /// @param _to address to receive the rewards
    function claimRewards(uint256 _tokenId, address _to) external nonReentrant {
        _requireClaimPermission(_to, _tokenId);
        _claimRewards(_tokenId, _to);
    }

    /// @notice claims all rewards distributed since token mint or last claim, and send them to another chain.
    /// @param _tokenId The tokenId of the twTAP position
    /// @param _rewardTokens The address of the reward token
    function claimAndSendRewards(
        uint256 _tokenId,
        IERC20[] memory _rewardTokens
    ) external nonReentrant {
        require(msg.sender == address(tapOFT), "twTAP: only tapOFT");
        _claimRewardsOn(_tokenId, address(tapOFT), _rewardTokens);
    }

    /// @notice claims the TAP locked in a position whose votes have expired,
    /// @notice and undoes the effect on the twAML calculations.
    /// @param _tokenId tokenId whose locked TAP to claim
    /// @param _to address to receive the TAP
    function releaseTap(uint256 _tokenId, address _to) external nonReentrant {
        _requireClaimPermission(_to, _tokenId);
        _releaseTap(_tokenId, _to);
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    /// @param _tokenId The tokenId of the twTAP position
    function exitPosition(uint256 _tokenId) external nonReentrant {
        address to = ownerOf(_tokenId);
        _releaseTap(_tokenId, to);
    }

    /// @notice Exit a twAML participation and send the withdrawn TAP to tapOFT to send it to another chain.
    /// @param _tokenId The tokenId of the twTAP position
    function exitPositionAndSendTap(
        uint256 _tokenId
    ) external nonReentrant returns (uint256) {
        require(msg.sender == address(tapOFT), "twTAP: only tapOFT");
        return _releaseTap(_tokenId, address(tapOFT));
    }

    /// @notice Indicate that (a) week(s) have passed and update running totals
    /// @notice Reverts if called in week 0. Let it.
    /// @param _limit Maximum number of weeks to process in one call
    function advanceWeek(uint256 _limit) public nonReentrant {
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
            // TODO: Prove that math is safe
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
    /// @notice Total rewards cannot exceed 2^128 tokens.
    /// @param _rewardTokenId index of the reward in `rewardTokens`
    /// @param _amount amount of reward token to distribute.
    function distributeReward(
        uint256 _rewardTokenId,
        uint256 _amount
    ) external nonReentrant {
        require(
            lastProcessedWeek == currentWeek(),
            "twTAP: Advance week first"
        );
        WeekTotals storage totals = weekTotals[lastProcessedWeek];
        IERC20 rewardToken = rewardTokens[_rewardTokenId];
        // If this is a DBZ then there are no positions to give the reward to.
        // Since reward eligibility starts in the week after locking, there is
        // no way to give out rewards THIS week.
        // Cast is safe: `netActiveVotes` is at most zero by construction of
        // weekly totals and the requirement that they are up to date.
        // TODO: Word this better
        totals.totalDistPerVote[_rewardTokenId] +=
            (_amount * DIST_PRECISION) /
            uint256(totals.netActiveVotes);

        require(_amount > 0, "twTap: amount is 0");
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    // =========
    //   OWNER
    // =========
    function setMaxRewardTokensLength(uint256 _length) external onlyOwner {
        emit LogMaxRewardsLength(maxRewardTokens, _length, rewardTokens.length);
        maxRewardTokens = _length;
    }

    function addRewardToken(IERC20 token) external onlyOwner returns (uint256) {
        if (rewardTokens.length > 0) {
            require(
                rewardTokenIndex[token] == 0 &&
                    address(rewardTokens[0]) != address(token),
                "twTap: token already registered"
            );
        }
        require(
            rewardTokens.length + 1 <= maxRewardTokens,
            "twTap: tokens limit reached"
        );
        uint256 i = rewardTokens.length;
        rewardTokens.push(token);
        rewardTokenIndex[token] = i;
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
        address tokenOwner = ownerOf(_tokenId);
        require(
            msg.sender == tokenOwner ||
                _to == tokenOwner ||
                isApprovedForAll(tokenOwner, msg.sender) ||
                getApproved(_tokenId) == msg.sender,
            "twTAP: cannot claim"
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

    function _claimRewardsOn(
        uint256 _tokenId,
        address _to,
        IERC20[] memory _rewardTokens
    ) internal {
        uint256[] memory amounts = claimable(_tokenId);
        address[] memory _reviewed = new address[](_rewardTokens.length);

        unchecked {
            uint256 len = _rewardTokens.length;
            for (uint256 i = 0; i < len; ) {
                // Check for duplicates
                require(
                    !_existInArray(address(_rewardTokens[i]), _reviewed),
                    "twTAP: duplicate reward token"
                );
                _reviewed[i] = address(_rewardTokens[i]);

                // Get amount and reward token index
                uint256 claimableIndex = rewardTokenIndex[_rewardTokens[i]];
                uint256 amount = amounts[i];

                if (amount > 0) {
                    // Math is safe: `amount` calculated safely in `claimable()`
                    claimed[_tokenId][claimableIndex] += amount;
                    rewardTokens[claimableIndex].safeTransfer(_to, amount);
                }
                ++i;
            }
        }
    }

    function _releaseTap(
        uint256 _tokenId,
        address _to
    ) internal returns (uint256 releasedAmount) {
        Participation memory position = participants[_tokenId];
        if (position.tapReleased) {
            return 0;
        }
        require(position.expiry <= block.timestamp, "twTAP: Lock not expired");

        releasedAmount = position.tapAmount;

        // Remove participation
        if (position.hasVotingPower) {
            TWAMLPool memory pool = twAML;
            unchecked {
                --pool.totalParticipants;
            }

            // Inverse of the participation. The participation entry tracks
            // the average magnitude as it was at the time the participant
            // entered. When going the other way around, this value matches the
            // one in the pool, but here it does not.
            if (position.divergenceForce) {
                if (pool.cumulative > position.averageMagnitude) {
                    pool.cumulative -= position.averageMagnitude;
                } else {
                    pool.cumulative = 0;
                }
            } else {
                pool.cumulative += position.averageMagnitude;
            }

            // Save new weight
            pool.totalDeposited -= position.tapAmount;

            twAML = pool; // Save twAML exit
            emit AMLDivergence(
                pool.cumulative,
                pool.averageMagnitude,
                pool.totalParticipants
            ); // Register new voting power event
        }

        participants[_tokenId].tapReleased = true;
        tapOFT.transfer(_to, releasedAmount);

        emit ExitPosition(_tokenId, releasedAmount);
    }

    /// @notice Checks if an element is in an array
    /// @param _check The element to check
    /// @param _array The array to check in
    function _existInArray(
        address _check,
        address[] memory _array
    ) internal pure returns (bool) {
        uint256 len = _array.length;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                if (_array[i] == _check) {
                    return true;
                }
            }
        }
        return false;
    }

    /// @dev Returns the chain ID of the current network
    function _getChainId() internal view virtual returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ONFT721, ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
