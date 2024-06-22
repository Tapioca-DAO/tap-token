// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Tapioca
import {IPearlmit, PearlmitHandler} from "tapioca-periph/pearlmit/PearlmitHandler.sol";
import {ERC721NftLoader} from "contracts/erc721NftLoader/ERC721NftLoader.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {ERC721Permit} from "tapioca-periph/utils/ERC721Permit.sol";
import {ERC721PermitStruct} from "contracts/tokens/ITapToken.sol";
import {TapToken} from "contracts/tokens/TapToken.sol";
import {TWAML} from "contracts/options/twAML.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

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
    // 1 slot
    uint256 averageMagnitude; // average magnitude of the pool at the time of locking.
    // 1 slot
    bool hasVotingPower;
    bool divergenceForce; // 0 negative, 1 positive
    bool tapReleased; // allow restaking while rewards may still accumulate
    uint56 lockedAt; // timestamp when lock was created. Since it's locked at block.timestamp, it's safe to say 56 bits will suffice
    // 1 slot
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

contract TwTAP is
    TWAML,
    ERC721,
    ERC721Permit,
    ERC721Enumerable,
    Ownable,
    PearlmitHandler,
    ERC721NftLoader,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    TapToken public immutable tapOFT;

    /// ===== TWAML ======
    TWAMLPool public twAML; // sglAssetId => twAMLPool

    mapping(uint256 => Participation) public participants; // tokenId => part.

    /// @dev Virtual total amount to add to the total when computing twAML participation right. Default 10_000 * 1e18.
    uint256 public VIRTUAL_TOTAL_AMOUNT = 10_000 ether;

    uint256 public MIN_WEIGHT_FACTOR = 1000; // In BPS, default 10%
    uint256 constant dMAX = 1_000_000; // 100 * 1e4; 0% - 100% voting power multiplier
    uint256 constant dMIN = 0;
    uint256 public constant EPOCH_DURATION = 7 days;
    uint256 public constant MAX_LOCK_DURATION = 100 * 365 days; // 100 years

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

    ICluster public cluster;

    bool rescueMode;
    uint256 public emergencySweepCooldown = 2 days;
    uint256 public lastEmergencySweep;

    error NotAuthorized();
    error AdvanceWeekFirst();
    error NotValid();
    error Registered();
    error TokenLimitReached();
    error NotApproved(uint256 tokenId, address spender);
    error Duplicate();
    error LockNotExpired();
    error LockNotAWeek();
    error LockTooLong();
    error AdvanceEpochFirst();
    error DurationNotMultiple(); // Lock duration should be a multiple of 1 EPOCH
    error EmergencySweepCooldownNotReached();

    /// =====-------======
    constructor(address payable _tapOFT, IPearlmit _pearlmit, address _owner)
        ERC721NftLoader("Time Weighted TAP", "twTAP", _owner)
        ERC721Permit("Time Weighted TAP")
        PearlmitHandler(_pearlmit)
    {
        tapOFT = TapToken(_tapOFT);
        creation = block.timestamp;

        rewardTokens.push(IERC20(address(0x0))); // 0 index is reserved

        maxRewardTokens = 30;

        // Seed the cumulative with 1 week of magnitude
        twAML.cumulative = EPOCH_DURATION;
    }

    // ==========
    //   EVENTS
    // ==========

    event AMLDivergence(
        uint256 indexed cumulative, uint256 indexed averageMagnitude, uint256 indexed totalParticipants
    );

    event AddRewardToken(address indexed rewardTokenAddress, uint256 rewardTokenIndex);
    event DistributeReward(
        address indexed rewardTokenAddress, address indexed from, uint256 amount, uint256 rewardTokenIndex
    );
    event AdvanceEpoch(uint256 indexed newEpoch, uint256 lastEpoch);

    event ClaimReward(
        address indexed rewardTokenAddress,
        address indexed to,
        uint256 indexed twTapTokenId,
        uint256 amount,
        uint256 rewardTokenIndex
    );
    event Participate(
        address indexed participant, uint256 mintedTokenId, uint256 tapAmount, uint256 multiplier, uint256 lockDuration
    );
    event ExitPosition(uint256 indexed twTapTokenId, address indexed releasedTo, uint256 amount);

    event LogMaxRewardsLength(uint256 _oldLength, uint256 _newLength, uint256 _currentLength);
    event SetMinWeightFactor(uint256 newMinWeightFactor, uint256 oldMinWeightFactor);
    event SetVirtualTotalAmount(uint256 newVirtualTotalAmount, uint256 oldVirtualTotalAmount);
    event RescueMode(bool _rescueMode);
    event SetCluster(address _cluster);
    event EmergencySweepLocks();
    event EmergencySweepRewards();
    event SetEmergencySweepCooldown(uint256 emergencySweepCooldown);
    event ActivateEmergencySweep();

    // ==========
    //    READ
    // ==========

    /**
     * @inheritdoc ERC721NftLoader
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721NftLoader) returns (string memory) {
        return ERC721NftLoader.tokenURI(tokenId);
    }

    /**
     * @notice Return the address of reward tokens.
     */
    function getRewardTokens() external view returns (IERC20[] memory) {
        return rewardTokens;
    }

    function currentWeek() public view returns (uint256) {
        return (block.timestamp - creation) / EPOCH_DURATION;
    }

    /**
     * @notice Return the total amount distributed for a reward token in a given week.
     * @param _week The week to query.
     * @param _rewardTokenId The reward token to query.
     */
    function getTotalDistPerVoteForWeek(uint256 _week, uint256 _rewardTokenId) external view returns (uint256) {
        return weekTotals[_week].totalDistPerVote[_rewardTokenId];
    }

    /// @notice Return the participation of a token. Returns 0 votes for expired tokens.
    function getParticipation(uint256 _tokenId) external view returns (Participation memory participant) {
        participant = participants[_tokenId];
        if (participant.expiry <= block.timestamp) {
            participant.multiplier = 0;
        }
        return participant;
    }

    /**
     * @notice Amount currently claimable for each reward token.
     * @dev index 0 will ALWAYS return 0, as it's used by address(0x0).
     * @dev Should be safe to claim even after position exit.
     * @return claimable amounts mapped by reward token
     */
    function claimable(uint256 _tokenId) public view returns (uint256[] memory) {
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

        for (uint256 i; i < len;) {
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
            //
            uint256 net = cur.totalDistPerVote[i] - prev.totalDistPerVote[i];
            result[i] = ((votes * net) / DIST_PRECISION) - claimed[_tokenId][i];
            unchecked {
                ++i;
            }
        }
        return result;
    }

    /// @notice Return the Participation of a token and the claimable amounts.
    /// @param _tokenId The tokenId of the twTAP position.
    /// @return position The Participation of the token.
    /// @return claimables The claimable amounts of each reward token.
    function getPosition(uint256 _tokenId)
        external
        view
        returns (Participation memory position, uint256[] memory claimables)
    {
        position = participants[_tokenId];
        claimables = claimable(_tokenId);
    }

    /**
     * @dev Returns the hash of the struct used by the permit function.
     * @param _permitData Struct containing permit data.
     */
    function getTypedDataHash(ERC721PermitStruct calldata _permitData) public view returns (bytes32) {
        bytes32 permitTypeHash_ = keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");

        bytes32 structHash_ = keccak256(
            abi.encode(
                permitTypeHash_, _permitData.spender, _permitData.tokenId, _permitData.nonce, _permitData.deadline
            )
        );
        return _hashTypedDataV4(structHash_);
    }

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in twAML voting and mint an twTap position
    ///         Lock duration should be a multiple of 1 EPOCH, and have a minimum of 1 EPOCH.
    /// @dev Requires a Pearlmit approval for the TAP amount
    ///
    /// @param _participant The address of the participant
    /// @param _amount The amount of TAP to participate with
    /// @param _duration The duration of the lock
    function participate(address _participant, uint256 _amount, uint256 _duration)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 tokenId)
    {
        if (_duration < EPOCH_DURATION) revert LockNotAWeek();
        if (_duration > MAX_LOCK_DURATION) revert LockTooLong();
        if (_duration % EPOCH_DURATION != 0) revert DurationNotMultiple();
        if (lastProcessedWeek != currentWeek()) revert AdvanceWeekFirst();

        // Transfer TAP to this contract
        {
            // tapOFT.transferFrom(msg.sender, address(this), _amount);
            bool isErr = pearlmit.transferFromERC20(msg.sender, address(this), address(tapOFT), _amount);
            if (isErr) revert NotAuthorized();
        }

        // Copy to memory
        TWAMLPool memory pool = twAML;

        uint256 magnitude = computeMagnitude(_duration, pool.cumulative);
        // Revert if the lock 4x the cumulative
        if (magnitude >= pool.cumulative * 4) revert NotValid();
        uint256 multiplier = computeTarget(dMIN, dMAX, magnitude, pool.cumulative);

        // Calculate twAML voting weight
        bool divergenceForce;
        bool hasVotingPower = _amount >= computeMinWeight(pool.totalDeposited + VIRTUAL_TOTAL_AMOUNT, MIN_WEIGHT_FACTOR);
        if (hasVotingPower) {
            pool.totalParticipants++; // Save participation
            pool.averageMagnitude = (pool.averageMagnitude + magnitude) / pool.totalParticipants; // compute new average magnitude

            // Compute and save new cumulative
            divergenceForce = _duration >= pool.cumulative;

            if (divergenceForce) {
                pool.cumulative += pool.averageMagnitude;
            } else {
                if (pool.cumulative > pool.averageMagnitude) {
                    pool.cumulative -= pool.averageMagnitude;
                } else {
                    pool.cumulative = EPOCH_DURATION;
                }
            }

            // Save new weight
            pool.totalDeposited += _amount;

            twAML = pool; // Save twAML participation
            emit AMLDivergence(pool.cumulative, pool.averageMagnitude, pool.totalParticipants);
        }

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
        tokenId = ++mintedTWTap;
        uint256 votes = _amount * multiplier;
        participants[tokenId] = Participation({
            averageMagnitude: pool.averageMagnitude,
            hasVotingPower: hasVotingPower,
            divergenceForce: divergenceForce,
            tapReleased: false,
            lockedAt: uint56(block.timestamp),
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

        // Mint twTAP position
        _safeMint(_participant, tokenId);

        emit Participate(_participant, tokenId, _amount, multiplier, _duration);
    }

    /**
     * @notice claims all rewards distributed since token mint or last claim.
     * @dev Should be safe to claim even after position exit.
     *
     * @param _tokenId tokenId whose rewards to claim
     *
     * @return amounts_ Claimed amount of each reward token.
     */
    function claimRewards(uint256 _tokenId) external nonReentrant whenNotPaused returns (uint256[] memory amounts_) {
        amounts_ = _claimRewardsForToken(_tokenId);
    }

    /**
     * @notice batch claims all rewards distributed since token mint or last claim.
     * @dev Should be safe to claim even after position exit.
     *
     * @param _tokenIds tokenIds whose rewards to claim
     *
     * @return amounts_ Claimed amountsof each reward token, for each tokenId
     */
    function batchClaimRewards(uint256[] calldata _tokenIds)
        external
        nonReentrant
        whenNotPaused
        returns (uint256[][] memory amounts_)
    {
        amounts_ = new uint256[][](_tokenIds.length);
        uint256 len = _tokenIds.length;
        for (uint256 i; i < len; i++) {
            amounts_[i] = _claimRewardsForToken(_tokenIds[i]);
        }
    }

    /**
     * @notice Exit a twAML participation, delete the voting power if existing and send the TAP to `_to`.
     *
     * @param _tokenId The tokenId of the twTAP position.
     *
     * @return tapAmount_ The amount of TAP released.
     */
    function exitPosition(uint256 _tokenId) external nonReentrant whenNotPaused returns (uint256 tapAmount_) {
        address owner_ = ownerOf(_tokenId);
        tapAmount_ = _releaseTap(_tokenId, owner_);
    }

    /// @notice Indicate that (a) week(s) have passed and update running totals
    /// @notice Reverts if called in week 0. Let it.
    /// @param _limit Maximum number of weeks to process in one call
    function advanceWeek(uint256 _limit) public nonReentrant {
        if (!cluster.hasRole(msg.sender, keccak256("NEW_EPOCH"))) revert NotAuthorized();

        uint256 week = lastProcessedWeek;
        uint256 goal = currentWeek();
        unchecked {
            if (goal - week > _limit) {
                goal = week + _limit;
            }
        }
        uint256 len = rewardTokens.length;
        while (week < goal) {
            WeekTotals storage prev = weekTotals[week];
            WeekTotals storage next = weekTotals[++week];

            next.netActiveVotes += prev.netActiveVotes;
            for (uint256 i; i < len;) {
                next.totalDistPerVote[i] += prev.totalDistPerVote[i];
                unchecked {
                    ++i;
                }
            }
        }
        emit AdvanceEpoch(goal, lastProcessedWeek);
        lastProcessedWeek = goal;
    }

    /// @notice distributes a reward among all tokens, weighted by voting power
    /// @notice The reward gets allocated to all positions that have locked in
    /// @notice the current week. Fails, intentionally, if this number is zero.
    /// @notice Total rewards cannot exceed 2^128 tokens.
    /// @param _rewardTokenId index of the reward in `rewardTokens`
    /// @param _amount amount of reward token to distribute.
    function distributeReward(uint256 _rewardTokenId, uint256 _amount) external nonReentrant {
        if (lastProcessedWeek != currentWeek()) revert AdvanceWeekFirst();
        if (_amount == 0) revert NotValid();
        if (_rewardTokenId == 0) revert NotValid(); // @dev rewardTokens[0] is 0x0

        WeekTotals storage totals = weekTotals[lastProcessedWeek];
        IERC20 rewardToken = rewardTokens[_rewardTokenId];
        // If this is a DBZ then there are no positions to give the reward to.
        // Since reward eligibility starts in the week after locking, there is
        // no way to give out rewards THIS week.
        // Cast is safe: `netActiveVotes` is at most zero by construction of
        // weekly totals and the requirement that they are up to date.
        totals.totalDistPerVote[_rewardTokenId] += (_amount * DIST_PRECISION) / uint256(totals.netActiveVotes);

        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit DistributeReward(address(rewardToken), msg.sender, _amount, _rewardTokenId);
    }

    // =========
    //   OWNER
    // =========
    /**
     * @notice Set the rescue mode.
     */
    function setRescueMode(bool _rescueMode) external onlyOwner {
        emit RescueMode(_rescueMode);
        rescueMode = _rescueMode;
    }

    /**
     * @notice Set the `VIRTUAL_TOTAL_AMOUNT` state variable.
     * @param _virtualTotalAmount The new state variable value.
     */
    function setVirtualTotalAmount(uint256 _virtualTotalAmount) external onlyOwner {
        emit SetVirtualTotalAmount(_virtualTotalAmount, VIRTUAL_TOTAL_AMOUNT);
        VIRTUAL_TOTAL_AMOUNT = _virtualTotalAmount;
    }

    /**
     * @notice Set the minimum weight factor.
     * @param _minWeightFactor The new minimum weight factor.
     */
    function setMinWeightFactor(uint256 _minWeightFactor) external onlyOwner {
        emit SetMinWeightFactor(_minWeightFactor, MIN_WEIGHT_FACTOR);
        MIN_WEIGHT_FACTOR = _minWeightFactor;
    }

    function setMaxRewardTokensLength(uint256 _length) external onlyOwner {
        emit LogMaxRewardsLength(maxRewardTokens, _length, rewardTokens.length);
        maxRewardTokens = _length;
    }

    /**
     * @notice Add a reward token to the list of reward tokens.
     * @param _token The address of the reward token.
     */
    function addRewardToken(IERC20 _token) external onlyOwner returns (uint256) {
        if (rewardTokenIndex[_token] != 0) revert Registered();
        if (rewardTokens.length + 1 > maxRewardTokens) {
            revert TokenLimitReached();
        }
        rewardTokens.push(_token);

        uint256 newTokenIndex = rewardTokens.length - 1;
        rewardTokenIndex[_token] = newTokenIndex;

        emit AddRewardToken(address(_token), newTokenIndex);

        return newTokenIndex;
    }

    /**
     * @notice updates the Cluster address.
     * @dev can only be called by the owner.
     * @param _cluster the new address.
     */
    function setCluster(ICluster _cluster) external onlyOwner {
        if (address(_cluster) == address(0)) revert NotValid();
        cluster = _cluster;
        emit SetCluster(address(_cluster));
    }

    /**
     * @notice Un/Pauses this contract.
     */
    function setPause(bool _pauseState) external {
        if (!cluster.hasRole(msg.sender, keccak256("PAUSABLE")) && msg.sender != owner()) revert NotAuthorized();
        if (_pauseState) {
            _pause();
        } else {
            _unpause();
        }
    }

    /**
     * @notice Set the emergency sweep cooldown
     */
    function setEmergencySweepCooldown(uint256 _emergencySweepCooldown) external onlyOwner {
        emergencySweepCooldown = _emergencySweepCooldown;
        emit SetEmergencySweepCooldown(_emergencySweepCooldown);
    }

    /**
     * @notice Activate the emergency sweep cooldown
     */
    function activateEmergencySweep() external onlyOwner {
        lastEmergencySweep = block.timestamp;
        emit ActivateEmergencySweep();
    }

    /**
     * @notice Emergency sweep of all tokens in case of a critical issue.
     * Strategy is to sweep tokens, then recreate positions with them on a new contract.
     *
     * @dev Only the owner with role `TWTAP_EMERGENCY_SWEEP` can call this function.
     */
    function emergencySweepLocks() external onlyOwner {
        if (block.timestamp < lastEmergencySweep + emergencySweepCooldown) revert EmergencySweepCooldownNotReached();
        if (!cluster.hasRole(msg.sender, keccak256("TWTAP_EMERGENCY_SWEEP"))) revert NotAuthorized();

        tapOFT.transfer(owner(), tapOFT.balanceOf(address(this)));
    }

    /**
     * @notice Emergency sweep of all rewards in case of a critical issue.
     * Strategy is to sweep tokens, then distribute reward on a new contract.
     *
     * @dev Only the owner with role `TWTAP_EMERGENCY_SWEEP` can call this function.
     */
    function emergencySweepRewards() external onlyOwner {
        if (block.timestamp < lastEmergencySweep + emergencySweepCooldown) revert EmergencySweepCooldownNotReached();
        if (!cluster.hasRole(msg.sender, keccak256("TWTAP_EMERGENCY_SWEEP"))) revert NotAuthorized();

        uint256 len = rewardTokens.length;
        // Index starts at 1, see constructor
        for (uint256 i = 1; i < len; ++i) {
            IERC20 token = rewardTokens[i];
            if (token != IERC20(address(0x0))) {
                token.safeTransfer(owner(), token.balanceOf(address(this)));
            }
        }
    }

    // ============
    //   INTERNAL
    // ============
    function _claimRewardsForToken(uint256 _tokenId) private returns (uint256[] memory amounts_) {
        // Either the owner or a delegate can claim the rewards
        // In this case it's `TapToken` to claim the rewards on behalf of the user and send them xChain.
        address owner = _ownerOf(_tokenId);

        if (owner != msg.sender && !isERC721Approved(owner, msg.sender, address(this), _tokenId)) {
            revert NotApproved(_tokenId, msg.sender);
        }

        amounts_ = _claimRewards(_tokenId, msg.sender);
    }

    /// @notice returns week for timestamp
    function _timestampToWeek(uint256 timestamp) internal view returns (uint256) {
        return ((timestamp - creation) / EPOCH_DURATION);
    }

    /**
     * @dev Claim rewards on a token.
     * @return amounts_ Claimed amount of each reward token.
     */
    function _claimRewards(uint256 _tokenId, address _to) internal returns (uint256[] memory amounts_) {
        amounts_ = claimable(_tokenId);
        uint256 len = amounts_.length;
        unchecked {
            for (uint256 i; i < len; ++i) {
                uint256 amount = amounts_[i];
                if (amount > 0) {
                    // Math is safe: `amount` calculated safely in `claimable()`
                    claimed[_tokenId][i] += amount;
                    rewardTokens[i].safeTransfer(_to, amount);
                    emit ClaimReward(address(rewardTokens[i]), _to, _tokenId, amount, i);
                }
            }
        }
    }

    /**
     * @notice Release the TAP locked in a position whose votes have expired.
     * @dev Clean up the twAML participation and delete the voting power if existing.
     * @dev !!!!!!!!!! Make sure to verify ownership of `_tokenId` and `_to` !!!!!!!!!!
     *
     * @param _tokenId tokenId whose locked TAP to claim
     * @param _to address to receive the TAP
     */
    function _releaseTap(uint256 _tokenId, address _to) internal returns (uint256 releasedAmount) {
        Participation memory position = participants[_tokenId];

        // If in rescue mode, allow the release of the TAP even if the lock has not expired.
        if (!rescueMode) {
            if (position.expiry > block.timestamp) revert LockNotExpired();
        }

        if (position.tapReleased) {
            return 0;
        }

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
                    pool.cumulative = EPOCH_DURATION;
                }
            } else {
                pool.cumulative += position.averageMagnitude;
            }

            // Save new weight
            pool.totalDeposited -= position.tapAmount;

            twAML = pool; // Save twAML exit
            emit AMLDivergence(pool.cumulative, pool.averageMagnitude, pool.totalParticipants); // Register new voting power event
        }

        participants[_tokenId].tapReleased = true;
        tapOFT.transfer(_to, releasedAmount);

        emit ExitPosition(_tokenId, _to, releasedAmount);
    }

    /// @notice Checks if an element is in an array
    /// @param _check The element to check
    /// @param _array The array to check in
    function _existInArray(address _check, address[] memory _array) internal pure returns (bool) {
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

    /// @notice Returns the chain ID of the current network.
    /// @dev Used for dev purposes.
    function _getChainId() internal view virtual returns (uint256) {
        return block.chainid;
    }

    function _baseURI() internal view override(ERC721, ERC721NftLoader) returns (string memory) {
        return baseURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        virtual
        override(ERC721, ERC721Permit)
    {
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
