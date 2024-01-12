// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ICommonOFT} from "tapioca-sdk/dist/contracts/token/oft/v2/ICommonOFT.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
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

// TODO: Prove that overflow is impossible
struct TWAMLPool {
    uint256 totalParticipants;
    uint256 averageMagnitude;
    uint256 totalDeposited;
    uint256 cumulative;
}
/// @dev Should be same as TWAMLPool, but with int256 instead of uint256 on `cumulative`
struct TWAMLExitPool {
    uint256 totalParticipants;
    uint256 averageMagnitude;
    uint256 totalDeposited;
    int256 cumulative;
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

contract TwTAP is
    TWAML,
    ERC721,
    ERC721Permit,
    BoringOwnable,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    TapOFT public immutable tapOFT;

    /// ===== TWAML ======
    TWAMLPool public twAML; // epoch => twAMLPool, Real twAML
    // TODO check for potential overflows
    mapping(uint256 epoch => TWAMLExitPool twAML) public twAMLExit; // epoch => TWAMLExitPool, pre computed exists, applied to twAML on `advanceWeek()`

    mapping(uint256 => Participation) public participants; // tokenId => part.

    uint256 constant MIN_WEIGHT_FACTOR = 10; // In BPS, 0.1%
    uint256 constant dMAX = 1_000_000; // 100 * 1e4; 10% - 100% voting power multiplier
    uint256 constant dMIN = 100_000; // 10 * 1e4;
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
    uint256 constant DIST_PRECISION = 2 ** 128; //2 ** 128;

    IERC20[] public rewardTokens;
    mapping(IERC20 => uint256) public rewardTokenIndex; // Index 0 is reserved with 0x0 address
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

    event LogMaxRewardsLength(
        uint256 indexed _oldLength,
        uint256 indexed _newLength,
        uint256 indexed _currentLength
    );

    error NotAuthorized();
    error AdvanceWeekFirst();
    error NotValid();
    error Registered();
    error TokenLimitReached();
    error CannotClaim();
    error Duplicate();
    error LockNotExpired();
    error LockNotAWeek();

    /// =====-------======
    constructor(
        address payable _tapOFT,
        address _owner
    ) ERC721("Time Weighted TAP", "twTAP") ERC721Permit("Time Weighted TAP") {
        tapOFT = TapOFT(_tapOFT);
        owner = _owner;
        creation = block.timestamp;

        rewardTokens.push(IERC20(address(0x0))); // 0 index is reserved

        maxRewardTokens = 1000;

        // Seed the cumulative with 1 week of magnitude
        twAML.cumulative = EPOCH_DURATION;
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(
        address indexed participant,
        uint256 indexed tapAmount,
        uint256 indexed multiplier
    );
    event AMLDivergence(
        uint256 indexed cumulative,
        uint256 indexed averageMagnitude,
        uint256 indexed totalParticipants
    );
    event ExitPosition(uint256 indexed tokenId, uint256 indexed amount);

    // ==========
    //    READ
    // ==========

    function currentWeek() public view returns (uint256) {
        return (block.timestamp - creation) / EPOCH_DURATION;
    }

    /// @notice Return the participation of a token. Returns 0 votes for expired tokens.
    function getParticipation(
        uint _tokenId
    ) external view returns (Participation memory participant) {
        participant = participants[_tokenId];
        if (participant.expiry <= block.timestamp) {
            participant.multiplier = 0;
        }
        return participant;
    }

    /// @notice Amount currently claimable for each reward token
    /// @dev index 0 will ALWAYS return 0, as it's used by address(0x0)
    /// @return claimable amounts mapped by reward token
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

        for (uint256 i; i < len; ) {
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

    /// @notice Participate in twAML voting and mint an twTap position
    /// @param _participant The address of the participant
    /// @param _amount The amount of TAP to participate with
    /// @param _duration The duration of the lock
    function participate(
        address _participant,
        uint256 _amount,
        uint256 _duration
    ) external whenNotPaused nonReentrant returns (uint256 tokenId) {
        if (_duration < EPOCH_DURATION) revert LockNotAWeek();

        // Transfer TAP to this contract
        tapOFT.transferFrom(msg.sender, address(this), _amount);

        // Copy to memory
        TWAMLPool memory pool = twAML;

        uint256 magnitude = computeMagnitude(_duration, pool.cumulative);
        // Revert if the lock 4x the cumulative
        if (magnitude >= pool.cumulative * 4) revert NotValid();
        uint256 multiplier = computeTarget(
            dMIN,
            dMAX,
            magnitude,
            pool.cumulative
        );

        // Calculate twAML voting weight
        bool divergenceForce;
        bool hasVotingPower = _amount >=
            computeMinWeight(pool.totalDeposited, MIN_WEIGHT_FACTOR);

        if (hasVotingPower) {
            pool.totalParticipants++; // Save participation
            pool.averageMagnitude =
                (pool.averageMagnitude + magnitude) /
                pool.totalParticipants; // compute new average magnitude

            // Compute and save new cumulative
            divergenceForce = _duration >= pool.cumulative;

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

        // Exit only if voting power is enough
        if (hasVotingPower) {
            // Prepare position exit
            uint256 exitWeek = _timestampToWeek(_duration + block.timestamp);
            TWAMLExitPool memory cachedExitWeek = twAMLExit[exitWeek];

            // Aggregate Exit position
            twAMLExit[exitWeek] = TWAMLExitPool({
                totalParticipants: cachedExitWeek.totalParticipants + 1,
                averageMagnitude: 0, // Not computed
                totalDeposited: cachedExitWeek.totalDeposited + _amount,
                cumulative: cachedExitWeek.cumulative +
                    (
                        divergenceForce
                            ? int256(pool.averageMagnitude)
                            : -int256(pool.averageMagnitude)
                    )
            });
        }

        emit Participate(_participant, _amount, multiplier);
        // TODO: Mint event?
    }

    /// @notice claims all rewards distributed since token mint or last claim.
    /// @param _tokenId tokenId whose rewards to claim
    /// @param _to address to receive the rewards
    function claimRewards(
        uint256 _tokenId,
        address _to
    ) external nonReentrant whenNotPaused {
        _requireClaimPermission(_to, _tokenId);
        _claimRewards(_tokenId, _to);
    }

    /// @notice claims all rewards distributed since token mint or last claim, and send them to another chain.
    /// @param _tokenId The tokenId of the twTAP position
    /// @param _rewardTokens The address of the reward token
    function claimAndSendRewards(
        uint256 _tokenId,
        IERC20[] calldata _rewardTokens
    ) external nonReentrant whenNotPaused {
        if (msg.sender != address(tapOFT)) revert NotAuthorized();
        _claimRewardsOn(_tokenId, address(tapOFT), _rewardTokens);
    }

    /// @notice claims the TAP locked in a position whose votes have expired,
    /// @notice and undoes the effect on the twAML calculations.
    /// @param _tokenId tokenId whose locked TAP to claim
    /// @param _to address to receive the TAP
    function releaseTap(
        uint256 _tokenId,
        address _to
    ) external nonReentrant whenNotPaused {
        _requireClaimPermission(_to, _tokenId);
        _releaseTap(_tokenId, _to);
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    /// @param _tokenId The tokenId of the twTAP position
    function exitPosition(
        uint256 _tokenId
    ) external nonReentrant whenNotPaused {
        address to = ownerOf(_tokenId);
        _releaseTap(_tokenId, to);
    }

    /// @notice Exit a twAML participation and send the withdrawn TAP to tapOFT to send it to another chain.
    /// @param _tokenId The tokenId of the twTAP position
    function exitPositionAndSendTap(
        uint256 _tokenId
    ) external nonReentrant whenNotPaused returns (uint256) {
        if (msg.sender != address(tapOFT)) revert NotAuthorized();
        return _releaseTap(_tokenId, address(tapOFT));
    }

    /// @notice Indicate that (a) week(s) have passed and update running totals
    /// @notice Reverts if called in week 0. Let it.
    /// @dev The function ports the running totals from the previous week to the new one
    /// @dev The function ports the twAML from the previous week to the new one, accounting for deltas
    /// @param _limit Maximum number of weeks to process in one call
    function advanceWeek(uint256 _limit) public nonReentrant whenNotPaused {
        // TODO: Make whole function unchecked?
        uint256 week = lastProcessedWeek;
        uint256 goal = currentWeek();

        // Port twAML state from prev week to new one
        TWAMLExitPool memory prevTwAMl = twAMLExit[goal];
        TWAMLPool memory currentTwAMl = twAML;

        // TODO check for overflows
        currentTwAMl.totalParticipants -= prevTwAMl.totalParticipants;
        currentTwAMl.totalDeposited -= prevTwAMl.totalDeposited;
        if (prevTwAMl.cumulative > 0) {
            currentTwAMl.cumulative -= uint256(prevTwAMl.cumulative);
        } else {
            currentTwAMl.cumulative += uint256(-prevTwAMl.cumulative);
        }

        // AverageMagnitude is not ported, it's computed on the fly on `participate()`
        twAML = currentTwAMl; // Update twAML

        // Port totals
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
            for (uint256 i; i < len; ) {
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
    ) external nonReentrant whenNotPaused {
        if (lastProcessedWeek != currentWeek()) revert AdvanceWeekFirst();
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

        if (_amount == 0) revert NotValid();
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    // =========
    //   OWNER
    // =========
    function setMaxRewardTokensLength(uint256 _length) external onlyOwner {
        if (_length <= rewardTokens.length) revert NotValid();
        emit LogMaxRewardsLength(maxRewardTokens, _length, rewardTokens.length);
        maxRewardTokens = _length;
    }

    function addRewardToken(IERC20 token) external onlyOwner returns (uint256) {
        if (rewardTokenIndex[token] != 0) revert Registered();
        if (rewardTokens.length + 1 > maxRewardTokens)
            revert TokenLimitReached();
        rewardTokens.push(token);

        uint256 newTokenIndex = rewardTokens.length - 1;
        rewardTokenIndex[token] = newTokenIndex;

        return newTokenIndex;
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
        if (
            msg.sender != tokenOwner &&
            _to != tokenOwner &&
            !isApprovedForAll(tokenOwner, msg.sender) &&
            getApproved(_tokenId) != msg.sender
        ) revert CannotClaim();
    }

    function _claimRewards(uint256 _tokenId, address _to) internal {
        uint256[] memory amounts = claimable(_tokenId);
        uint256 len = amounts.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
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
            for (uint256 i; i < len; ) {
                // Check for duplicates
                if (_existInArray(address(_rewardTokens[i]), _reviewed))
                    revert Duplicate();
                _reviewed[i] = address(_rewardTokens[i]);

                // Get amount and reward token index
                uint256 claimableIndex = rewardTokenIndex[_rewardTokens[i]];
                uint256 amount = amounts[claimableIndex];

                //if caller uses a token that is not in the list, it will be skipped
                // Because index would target address(0x0)
                if (amount > 0) {
                    // Math is safe: `amount` calculated safely in `claimable()`
                    claimed[_tokenId][claimableIndex] += amount;
                    rewardTokens[claimableIndex].safeTransfer(_to, amount);
                }
                ++i;
            }
        }
    }

    /**
     * @notice Release the TAP position and transfer it to `_to`.
     */
    function _releaseTap(
        uint256 _tokenId,
        address _to
    ) internal returns (uint256 releasedAmount) {
        Participation memory position = participants[_tokenId];
        if (position.expiry > block.timestamp) revert LockNotExpired();
        if (position.tapReleased) {
            return 0;
        }

        releasedAmount = position.tapAmount;
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
            for (uint256 i; i < len; ++i) {
                if (_array[i] == _check) {
                    return true;
                }
            }
        }
        return false;
    }

    /// @notice returns week for timestamp
    function _timestampToWeek(
        uint256 timestamp
    ) internal view returns (uint256) {
        return ((timestamp - creation) / EPOCH_DURATION);
    }

    /// @notice Returns the chain ID of the current network.
    /// @dev Used for dev purposes.
    function _getChainId() internal view virtual returns (uint256) {
        return block.chainid;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
