// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Tapioca
import {TapiocaOptionLiquidityProvision, LockPosition, SingularityPool} from "./TapiocaOptionLiquidityProvision.sol";
import {ITobMagnitudeMultiplier} from "contracts/interfaces/IMagnitudeMultiplier.sol";
import {IPearlmit, PearlmitHandler} from "tap-utils/pearlmit/PearlmitHandler.sol";
import {ITapiocaOracle} from "tap-utils/interfaces/periph/ITapiocaOracle.sol";
import {ICluster} from "tap-utils/interfaces/periph/ICluster.sol";
import {TapToken} from "contracts/tokens/TapToken.sol";
import {OTAP, TapOption} from "./oTAP.sol";
import {TWAML} from "./twAML.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

struct Participation {
    bool hasVotingPower;
    bool divergenceForce; // 0 negative, 1 positive
    uint256 averageMagnitude;
}

struct TWAMLPool {
    uint256 totalParticipants;
    uint256 averageMagnitude;
    uint256 totalDeposited;
    uint256 cumulative;
}

struct PaymentTokenOracle {
    ITapiocaOracle oracle;
    bytes oracleData;
}

contract TapiocaOptionBroker is Pausable, Ownable, PearlmitHandler, IERC721Receiver, TWAML, ReentrancyGuard {
    using SafeERC20 for IERC20;

    TapiocaOptionLiquidityProvision public immutable tOLP;
    bytes public tapOracleData;
    TapToken public immutable tapOFT;
    OTAP public immutable oTAP;
    ITapiocaOracle public tapOracle;

    ICluster public cluster;

    uint256 public epochTAPValuation; // TAP price for the current epoch
    uint256 public epoch; // Represents the number of weeks since the start of the contract

    mapping(uint256 => Participation) public participants; // tOLPTokenID => Participation
    mapping(uint256 => mapping(uint256 => uint256)) public oTAPCalls; // oTAPTokenID => epoch => amountExercised

    mapping(uint256 => mapping(uint256 => uint256)) public singularityGauges; // epoch => sglAssetId => availableTAP

    mapping(ERC20 => PaymentTokenOracle) public paymentTokens; // Token address => PaymentTokenOracle
    address public paymentTokenBeneficiary; // Where to collect the payment tokens

    /// ===== TWAML ======
    mapping(uint256 => TWAMLPool) public twAML; // sglAssetId => twAMLPool

    /// @dev Virtual total amount to add to the total when computing twAML participation right. Default 10_000 * 1e18.
    uint256 private VIRTUAL_TOTAL_AMOUNT = 10_000 ether;

    uint256 public MIN_WEIGHT_FACTOR = 1000; // In BPS, default 10%
    uint256 constant dMAX = 500_000; // 50 * 1e4; 0% - 50% discount
    uint256 constant dMIN = 0;
    uint256 public immutable EPOCH_DURATION; // 7 days = 604800

    uint256 public maxEpochCoeff = 4; // Maximum epoch coefficient for the cumulative

    /// @notice starts time for emissions
    /// @dev initialized in the constructor with block.timestamp
    uint256 public emissionsStartTime;

    /// @notice Total amount of participation per epoch
    mapping(uint256 epoch => mapping(uint256 sglAssetID => int256 netAmount)) public netDepositedForEpoch;

    /// @notice Cumulative for each epoch
    mapping(uint256 sglAssetID => uint256 cumulative) public lastEpochCumulativeForSgl;

    /// @notice The maximum epoch coefficient for the cumulative
    ITobMagnitudeMultiplier public tobMagnitudeMultiplier;
    uint256 constant MULTIPLIER_PRECISION = 1e18;

    /// =====-------======

    error NotEqualDurations();
    error NotAuthorized();
    error NoActiveSingularities();
    error NoLiquidity();
    error OptionExpired();
    error PaymentTokenNotSupported();
    error OneEpochCooldown();
    error TooHigh();
    error TooLong();
    error TooLow();
    error DurationTooShort();
    error PositionNotValid();
    error LockNotExpired();
    error TooSoon();
    error Failed();
    error TransferFailed();
    error SingularityInRescueMode();
    error PaymentTokenValuationNotValid();
    error LockExpired();
    error AdvanceEpochFirst();
    error DurationNotMultiple();
    error NotValid();

    constructor(
        address _tOLP,
        address _oTAP,
        address payable _tapOFT,
        address _paymentTokenBeneficiary,
        uint256 _epochDuration,
        IPearlmit _pearlmit,
        address _owner
    ) PearlmitHandler(_pearlmit) {
        paymentTokenBeneficiary = _paymentTokenBeneficiary;
        tOLP = TapiocaOptionLiquidityProvision(_tOLP);

        if (_epochDuration != TapiocaOptionLiquidityProvision(_tOLP).EPOCH_DURATION()) revert NotEqualDurations();

        tapOFT = TapToken(_tapOFT);
        oTAP = OTAP(_oTAP);
        EPOCH_DURATION = _epochDuration;

        _transferOwnership(_owner);
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(
        uint256 indexed epoch,
        uint256 indexed sglAssetId,
        uint256 totalDeposited,
        uint256 otapTokenId,
        uint256 tolpTokenId,
        uint256 discount
    );
    event AMLDivergence(uint256 indexed epoch, uint256 cumulative, uint256 averageMagnitude, uint256 totalParticipants);
    event ExerciseOption(
        uint256 indexed epoch, address indexed to, ERC20 indexed paymentToken, uint256 otapTokenId, uint256 tapAmount
    );
    event NewEpoch(uint256 indexed epoch, uint256 extractedTap, uint256 epochTapValuation);
    event ExitPosition(uint256 indexed epoch, uint256 indexed otapTokenId, uint256 tolpTokenId);
    event SetPaymentToken(ERC20 indexed paymentToken, ITapiocaOracle oracle, bytes oracleData);
    event SetTapOracle(ITapiocaOracle oracle, bytes oracleData);

    // ==========
    //    READ
    // ==========
    /// @notice Returns the current week given a timestamp
    function timestampToWeek(uint256 timestamp) external view returns (uint256) {
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        if (timestamp < emissionsStartTime) return 0;

        return _timestampToWeek(timestamp);
    }

    /// @notice Returns the current week
    function getCurrentWeek() external view returns (uint256) {
        return _timestampToWeek(block.timestamp);
    }

    /// @notice Returns the details of an oTAP position including its tOLP lock position
    /// @param _oTAPTokenID The oTAP token ID
    /// @param epochId The epoch id of which to get the claimed TAP for - if 0, current epoch will be used
    /// @return tOLPLockPosition The tOLP lock position of the oTAP position
    /// @return oTAPPosition The details of the oTAP position
    /// @return claimedTapInEpoch The amount of TAP claimed in specified epoch
    function getOptionPosition(uint256 _oTAPTokenID, uint256 epochId)
        external
        view
        returns (LockPosition memory tOLPLockPosition, TapOption memory oTAPPosition, uint256 claimedTapInEpoch)
    {
        if (epochId == 0) {
            epochId = epoch;
        }

        (, oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        tOLPLockPosition = tOLP.getLock(oTAPPosition.tOLP);
        claimedTapInEpoch = oTAPCalls[_oTAPTokenID][epochId];
    }

    /// @notice Returns the details of TOLP Singularity Pool, twAML pool and gauge for a given sglAssetId
    /// @param _singularity The singularity address
    /// @param epochId The epoch id of which to get the tap emitted for the pool - if 0, current epoch will be used
    /// @return assetId The Singularity asset id = YB asset id
    /// @return totalDeposited The total deposited amount in the pool
    /// @return weight The weight of the pool
    /// @return isInRescue True if the singularity is in rescue mode
    /// @return tapEmittedInCurrentEpoch The amount of TAP emitted in the current epoch
    /// @return twAMLPool The twAML Pool details
    function getSingularityPoolInfo(IERC20 _singularity, uint256 epochId)
        external
        view
        returns (
            uint256 assetId,
            uint256 totalDeposited,
            uint256 weight,
            bool isInRescue,
            uint256 tapEmittedInCurrentEpoch,
            TWAMLPool memory twAMLPool
        )
    {
        if (epochId == 0) {
            epochId = epoch;
        }

        (assetId, totalDeposited, weight, isInRescue) = tOLP.activeSingularities(_singularity);
        twAMLPool = twAML[assetId];
        tapEmittedInCurrentEpoch = singularityGauges[epochId][assetId];
    }

    /// @notice Returns the details of an OTC deal for a given oTAP token ID and a payment token.
    ///         The oracle uses the last peeked value, and not the latest one, so the payment amount may be different.
    /// @param _oTAPTokenID The oTAP token ID
    /// @param _paymentToken The payment token
    /// @param _tapAmount The amount of TAP to be exchanged. If 0 it will use the full amount of TAP eligible for the deal
    /// @return eligibleTapAmount The amount of TAP eligible for the deal
    /// @return paymentTokenAmount The amount of payment tokens required for the deal
    /// @return tapAmount The amount of TAP to be exchanged
    function getOTCDealDetails(uint256 _oTAPTokenID, ERC20 _paymentToken, uint256 _tapAmount)
        external
        view
        returns (uint256 eligibleTapAmount, uint256 paymentTokenAmount, uint256 tapAmount)
    {
        // Load data
        (, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        LockPosition memory tOLPLockPosition = tOLP.getLock(oTAPPosition.tOLP);

        {
            if (!_isPositionActive(tOLPLockPosition)) revert OptionExpired();
        }

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[_paymentToken];

        // Check requirements
        if (paymentTokenOracle.oracle == ITapiocaOracle(address(0))) {
            revert PaymentTokenNotSupported();
        }
        if (block.timestamp < tOLPLockPosition.lockTime + EPOCH_DURATION) {
            revert OneEpochCooldown();
        } // Can only exercise after 1 epoch duration

        // Get eligible OTC amount
        {
            uint256 gaugeTotalForEpoch = singularityGauges[cachedEpoch][tOLPLockPosition.sglAssetID];
            uint256 netAmount = uint256(netDepositedForEpoch[cachedEpoch][tOLPLockPosition.sglAssetID]);
            if (netAmount == 0) revert NoLiquidity();

            eligibleTapAmount = muldiv(tOLPLockPosition.ybShares, gaugeTotalForEpoch, netAmount);
            eligibleTapAmount -= oTAPCalls[_oTAPTokenID][cachedEpoch]; // Subtract already exercised amount
            if (eligibleTapAmount < _tapAmount) revert TooHigh();
        }

        tapAmount = _tapAmount == 0 ? eligibleTapAmount : _tapAmount;
        if (tapAmount < 1e18) revert TooLow();
        // Get TAP valuation
        uint256 otcAmountInUSD = tapAmount * epochTAPValuation; // Divided by TAP decimals
        // Get payment token valuation
        (, uint256 paymentTokenValuation) = paymentTokenOracle.oracle.peek(paymentTokenOracle.oracleData);
        // Get payment token amount
        paymentTokenAmount = _getDiscountedPaymentAmount(
            otcAmountInUSD, paymentTokenValuation, oTAPPosition.discount, _paymentToken.decimals()
        );
    }

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in twAMl voting and mint an oTAP position.
    ///         Exercising the option is not possible on participation week.
    ///         Lock duration should be a multiple of 1 EPOCH, and have a minimum of 1 EPOCH.
    /// @param _tOLPTokenID The tokenId of the tOLP position
    function participate(uint256 _tOLPTokenID) external whenNotPaused nonReentrant returns (uint256 oTAPTokenID) {
        // Compute option parameters
        LockPosition memory lock = tOLP.getLock(_tOLPTokenID);
        uint128 lockExpiry = lock.lockTime + lock.lockDuration;

        if (block.timestamp >= lockExpiry) revert LockExpired();
        if (_timestampToWeek(block.timestamp) > epoch) revert AdvanceEpochFirst();

        bool isPositionActive = _isPositionActive(lock);
        if (!isPositionActive) revert OptionExpired();

        if (lock.lockDuration < EPOCH_DURATION) revert DurationTooShort();
        if (lock.lockDuration % EPOCH_DURATION != 0) revert DurationNotMultiple();

        TWAMLPool memory pool = twAML[lock.sglAssetID];

        if (pool.cumulative == 0) {
            pool.cumulative = EPOCH_DURATION;
        }

        // Transfer tOLP position to this contract
        // tOLP.transferFrom(msg.sender, address(this), _tOLPTokenID);
        {
            bool isErr = pearlmit.transferFromERC721(msg.sender, address(this), address(tOLP), _tOLPTokenID);
            if (isErr) revert TransferFailed();
        }

        uint256 magnitude = computeMagnitude(uint256(lock.lockDuration), pool.cumulative);
        uint256 target = computeTarget(dMIN, dMAX, magnitude, pool.cumulative);

        // Revert if the lock 4x the last epoch cumulative
        {
            uint256 lastEpochCumulative = lastEpochCumulativeForSgl[lock.sglAssetID]; // Get the last epoch cumulative
            if (lastEpochCumulative == 0) {
                lastEpochCumulative = EPOCH_DURATION;
            }

            if (magnitude > lastEpochCumulative * maxEpochCoeff) revert TooLong();
        }

        bool divergenceForce;
        // Participate in twAMl voting
        bool hasVotingPower =
            lock.ybShares >= computeMinWeight(pool.totalDeposited + VIRTUAL_TOTAL_AMOUNT, MIN_WEIGHT_FACTOR);
        if (hasVotingPower) {
            pool.totalParticipants++; // Save participation
            pool.averageMagnitude = (pool.averageMagnitude + magnitude) / pool.totalParticipants; // compute new average magnitude

            // Compute and save new cumulative
            divergenceForce = lock.lockDuration >= pool.cumulative;
            if (divergenceForce) {
                uint256 aMagnitudeMultiplier = MULTIPLIER_PRECISION;
                if (address(tobMagnitudeMultiplier) != address(0)) {
                    aMagnitudeMultiplier = tobMagnitudeMultiplier.getPositiveMagnitudeMultiplier(_tOLPTokenID);
                }

                pool.cumulative += (pool.averageMagnitude * aMagnitudeMultiplier / MULTIPLIER_PRECISION);
            } else {
                if (pool.cumulative > pool.averageMagnitude) {
                    uint256 aMagnitudeMultiplier = MULTIPLIER_PRECISION;
                    if (address(tobMagnitudeMultiplier) != address(0)) {
                        aMagnitudeMultiplier = tobMagnitudeMultiplier.getNegativeMagnitudeMultiplier(_tOLPTokenID);
                    }

                    pool.cumulative -= (pool.averageMagnitude * aMagnitudeMultiplier / MULTIPLIER_PRECISION);
                    if (pool.cumulative < EPOCH_DURATION) {
                        pool.cumulative = EPOCH_DURATION;
                    }
                } else {
                    pool.cumulative = EPOCH_DURATION;
                }
            }

            // Save new weight
            pool.totalDeposited += lock.ybShares;

            twAML[lock.sglAssetID] = pool; // Save twAML participation
            emit AMLDivergence(epoch, pool.cumulative, pool.averageMagnitude, pool.totalParticipants); // Register new voting power event
        }
        // Save twAML participation
        participants[_tOLPTokenID] = Participation(hasVotingPower, divergenceForce, pool.averageMagnitude);

        // Record amount for next epoch exercise
        netDepositedForEpoch[epoch + 1][lock.sglAssetID] += int256(uint256(lock.ybShares));

        uint256 lastEpoch = _timestampToWeek(lockExpiry);
        // And remove it from last epoch
        // Math is safe, check `_emitToGauges()`
        netDepositedForEpoch[lastEpoch + 1][lock.sglAssetID] -= int256(uint256(lock.ybShares));

        // Mint oTAP position
        oTAPTokenID = oTAP.mint(msg.sender, lockExpiry, uint128(target), _tOLPTokenID);
        emit Participate(epoch, lock.sglAssetID, pool.totalDeposited, oTAPTokenID, _tOLPTokenID, target);
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    /// @param _oTAPTokenID The tokenId of the oTAP position
    function exitPosition(uint256 _oTAPTokenID) external whenNotPaused {
        if (!oTAP.exists(_oTAPTokenID)) revert PositionNotValid();

        // Load data
        (, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        LockPosition memory lock = tOLP.getLock(oTAPPosition.tOLP);

        bool isSGLInRescueMode = _isSGLInRescueMode(lock);

        // If SGL is in rescue, bypass the lock expiration
        if (!isSGLInRescueMode) {
            if (block.timestamp < lock.lockTime + lock.lockDuration) {
                revert LockNotExpired();
            }
        }

        Participation memory participation = participants[oTAPPosition.tOLP];

        // Remove participation
        // If the SGL is in rescue mode, bypass the voting power removal
        if (!isSGLInRescueMode && participation.hasVotingPower) {
            TWAMLPool memory pool = twAML[lock.sglAssetID];

            if (participation.divergenceForce) {
                if (pool.cumulative > participation.averageMagnitude) {
                    pool.cumulative -= participation.averageMagnitude;
                } else {
                    pool.cumulative = EPOCH_DURATION;
                }
            } else {
                pool.cumulative += participation.averageMagnitude;
            }

            pool.totalDeposited -= lock.ybShares;

            unchecked {
                --pool.totalParticipants;
            }

            twAML[lock.sglAssetID] = pool; // Save twAML exit
            emit AMLDivergence(epoch, pool.cumulative, pool.averageMagnitude, pool.totalParticipants); // Register new voting power event
        }

        // Delete participation and burn oTAP position
        address otapOwner = oTAP.ownerOf(_oTAPTokenID);
        delete participants[oTAPPosition.tOLP];
        oTAP.burn(_oTAPTokenID);

        // Transfer position back to oTAP owner
        tOLP.transferFrom(address(this), otapOwner, oTAPPosition.tOLP);

        emit ExitPosition(epoch, _oTAPTokenID, oTAPPosition.tOLP);
    }

    /// @notice Exercise an oTAP position
    /// @param _oTAPTokenID tokenId of the oTAP position, position must be active
    /// @param _paymentToken Address of the payment token to use, must be whitelisted
    /// @param _tapAmount Amount of TAP to exercise. If 0, the full amount is exercised
    function exerciseOption(uint256 _oTAPTokenID, ERC20 _paymentToken, uint256 _tapAmount) external whenNotPaused {
        // Load data
        (address owner, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        LockPosition memory tOLPLockPosition = tOLP.getLock(oTAPPosition.tOLP);
        {
            bool isPositionActive = _isPositionActive(tOLPLockPosition);
            if (!isPositionActive) revert OptionExpired();
        }

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[_paymentToken];

        // Check requirements
        if (paymentTokenOracle.oracle == ITapiocaOracle(address(0))) {
            revert PaymentTokenNotSupported();
        }

        // Check allowance. Make sure to consume it post call
        {
            // oTAP.isApprovedOrOwner(msg.sender, _oTAPTokenID)
            if (owner != msg.sender && !isERC721Approved(owner, msg.sender, address(oTAP), _oTAPTokenID)) {
                revert NotAuthorized();
            }
        }

        if (_timestampToWeek(block.timestamp) > epoch) revert AdvanceEpochFirst();

        if (block.timestamp < oTAPPosition.entry + EPOCH_DURATION) {
            revert OneEpochCooldown();
        } // Can only exercise after 1 epoch duration

        // Get eligible OTC amount
        uint256 gaugeTotalForEpoch = singularityGauges[cachedEpoch][tOLPLockPosition.sglAssetID];
        uint256 netAmount = uint256(netDepositedForEpoch[cachedEpoch][tOLPLockPosition.sglAssetID]);
        if (netAmount == 0) revert NoLiquidity();
        uint256 eligibleTapAmount = muldiv(tOLPLockPosition.ybShares, gaugeTotalForEpoch, netAmount);
        eligibleTapAmount -= oTAPCalls[_oTAPTokenID][cachedEpoch]; // Subtract already exercised amount
        if (eligibleTapAmount < _tapAmount) revert TooHigh();

        uint256 chosenAmount = _tapAmount == 0 ? eligibleTapAmount : _tapAmount;
        if (chosenAmount < 1e18) revert TooLow();
        oTAPCalls[_oTAPTokenID][cachedEpoch] += chosenAmount; // Adds up exercised amount to current epoch

        // Finalize the deal
        _processOTCDeal(_paymentToken, paymentTokenOracle, chosenAmount, oTAPPosition.discount);

        emit ExerciseOption(cachedEpoch, msg.sender, _paymentToken, _oTAPTokenID, chosenAmount);
    }

    // TODO Check at how many SGls this function breaks. Do we need to split calls into 2+ Txs?
    /// @notice Start a new epoch, extract TAP from the TapOFT contract,
    ///         emit it to the active singularities and get the price of TAP for the epoch.
    function newEpoch() external {
        if (!cluster.hasRole(msg.sender, keccak256("NEW_EPOCH"))) revert NotAuthorized();
        if (_timestampToWeek(block.timestamp) <= epoch) revert TooSoon();

        uint256[] memory singularities = tOLP.getSingularities();
        uint256 sglLen = singularities.length;
        if (sglLen == 0) revert NoActiveSingularities();

        epoch++;

        // Update the lastEpochCumulativeForSgl on each active singularity
        for (uint256 i; i < sglLen; i++) {
            uint256 sglAssetId = singularities[i];
            TWAMLPool memory twAMLPool = twAML[sglAssetId];
            lastEpochCumulativeForSgl[sglAssetId] = twAMLPool.cumulative;
        }

        // Extract TAP + emit to gauges
        uint256 epochTAP = tapOFT.emitForWeek();
        _emitToGauges(epochTAP);

        // Get epoch TAP valuation
        bool success;
        (success, epochTAPValuation) = tapOracle.get(tapOracleData);
        if (!success) revert Failed();
        emit NewEpoch(epoch, epochTAP, epochTAPValuation);
    }

    /// @notice Claim the Broker role of the oTAP contract. Init emissions on TOB and TapToken.
    /// @dev Can only be called once. External calls should revert if already called.
    function init() external {
        oTAP.brokerClaim();

        emissionsStartTime = block.timestamp;
        tapOFT.initEmissions();
    }

    // =========
    //   OWNER
    // =========

    function setTobMagnitudeMultiplier(ITobMagnitudeMultiplier _tobMagnitudeMultiplier) external onlyOwner {
        tobMagnitudeMultiplier = _tobMagnitudeMultiplier;
    }

    function setMaxEpochCoeff(uint256 _maxEpochCoeff) external onlyOwner {
        maxEpochCoeff = _maxEpochCoeff;
    }

    /**
     * @notice Set the `VIRTUAL_TOTAL_AMOUNT` state variable.
     * @param _virtualTotalAmount The new state variable value.
     */
    function setVirtualTotalAmount(uint256 _virtualTotalAmount) external onlyOwner {
        VIRTUAL_TOTAL_AMOUNT = _virtualTotalAmount;
    }

    /**
     * @notice Set the minimum weight factor.
     * @param _minWeightFactor The new minimum weight factor.
     */
    function setMinWeightFactor(uint256 _minWeightFactor) external onlyOwner {
        MIN_WEIGHT_FACTOR = _minWeightFactor;
    }

    /// @notice Set the TapOFT Oracle address and data
    /// @param _tapOracle The new TapOFT Oracle address
    /// @param _tapOracleData The new TapOFT Oracle data
    function setTapOracle(ITapiocaOracle _tapOracle, bytes calldata _tapOracleData) external onlyOwner {
        tapOracle = _tapOracle;
        tapOracleData = _tapOracleData;

        emit SetTapOracle(_tapOracle, _tapOracleData);
    }

    /// @notice Activate or deactivate a payment token
    /// @dev set the oracle to address(0) to deactivate, expect the same decimal precision as TAP oracle
    function setPaymentToken(ERC20 _paymentToken, ITapiocaOracle _oracle, bytes calldata _oracleData)
        external
        onlyOwner
    {
        paymentTokens[_paymentToken].oracle = _oracle;
        paymentTokens[_paymentToken].oracleData = _oracleData;

        emit SetPaymentToken(_paymentToken, _oracle, _oracleData);
    }

    /// @notice Set the payment token beneficiary
    /// @param _paymentTokenBeneficiary The new payment token beneficiary
    function setPaymentTokenBeneficiary(address _paymentTokenBeneficiary) external onlyOwner {
        paymentTokenBeneficiary = _paymentTokenBeneficiary;
    }

    /// @notice Collect the payment tokens from the OTC deals
    /// @param _paymentTokens The payment tokens to collect
    function collectPaymentTokens(address[] calldata _paymentTokens) external onlyOwner nonReentrant {
        address _paymentTokenBeneficiary = paymentTokenBeneficiary;
        if (_paymentTokenBeneficiary == address(0)) {
            revert PaymentTokenNotSupported();
        }
        uint256 len = _paymentTokens.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                IERC20 paymentToken = IERC20(_paymentTokens[i]);
                paymentToken.safeTransfer(_paymentTokenBeneficiary, paymentToken.balanceOf(address(this)));
            }
        }
    }

    /**
     * @notice updates the Cluster address.
     * @dev can only be called by the owner.
     * @param _cluster the new address.
     */
    function setCluster(ICluster _cluster) external onlyOwner {
        if (address(_cluster) == address(0)) revert NotValid();
        cluster = _cluster;
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

    // ============
    //   INTERNAL
    // ============
    /// @notice returns week for timestamp
    function _timestampToWeek(uint256 timestamp) internal view returns (uint256) {
        return ((timestamp - emissionsStartTime) / EPOCH_DURATION);
    }

    /// @notice Check if a singularity is in rescue mode
    /// @param _lock The lock position
    function _isSGLInRescueMode(LockPosition memory _lock) internal view returns (bool) {
        (,,, bool rescue) = tOLP.activeSingularities(tOLP.sglAssetIDToAddress(_lock.sglAssetID));
        return rescue;
    }

    /// @notice Check if a position is active, whether it is expired or SGL is in rescue mode
    /// @dev Check if the current week is less than or equal the expiry week
    /// @param _lock The lock position
    /// @return isPositionActive True if the position is active
    function _isPositionActive(LockPosition memory _lock) internal view returns (bool isPositionActive) {
        if (_lock.lockTime == 0) revert PositionNotValid();
        if (_isSGLInRescueMode(_lock)) revert SingularityInRescueMode();

        uint256 expiryWeek = _timestampToWeek(_lock.lockTime + _lock.lockDuration);

        isPositionActive = epoch <= expiryWeek;
    }

    /// @notice Process the OTC deal, transfer the payment token to the broker and the TAP amount to the user
    /// @param _paymentToken The payment token
    /// @param _paymentTokenOracle The oracle of the payment token
    /// @param tapAmount The amount of TAP that the user has to receive
    /// @param discount The discount that the user has to apply to the OTC deal
    function _processOTCDeal(
        ERC20 _paymentToken,
        PaymentTokenOracle memory _paymentTokenOracle,
        uint256 tapAmount,
        uint256 discount
    ) internal {
        // Get TAP valuation
        uint256 otcAmountInUSD = tapAmount * epochTAPValuation;

        // Get payment token valuation
        (bool success, uint256 paymentTokenValuation) = _paymentTokenOracle.oracle.get(_paymentTokenOracle.oracleData);
        if (!success) revert Failed();

        // Calculate payment amount and initiate the transfers
        uint256 discountedPaymentAmount =
            _getDiscountedPaymentAmount(otcAmountInUSD, paymentTokenValuation, discount, _paymentToken.decimals());

        uint256 balBefore = _paymentToken.balanceOf(address(this));
        // IERC20(address(_paymentToken)).safeTransferFrom(msg.sender, address(this), discountedPaymentAmount);
        {
            bool isErr =
                pearlmit.transferFromERC20(msg.sender, address(this), address(_paymentToken), discountedPaymentAmount);
            if (isErr) revert TransferFailed();
        }
        uint256 balAfter = _paymentToken.balanceOf(address(this));
        if (balAfter - balBefore != discountedPaymentAmount) {
            revert TransferFailed();
        }

        tapOFT.extractTAP(msg.sender, tapAmount);
    }

    /// @notice Computes the discounted payment amount for a given OTC amount in USD
    /// @param _otcAmountInUSD The OTC amount in USD, 18 decimals
    /// @param _paymentTokenValuation The payment token valuation in USD, 18 decimals
    /// @param _discount The discount in BPS
    /// @param _paymentTokenDecimals The payment token decimals
    /// @return paymentAmount The discounted payment amount
    function _getDiscountedPaymentAmount(
        uint256 _otcAmountInUSD,
        uint256 _paymentTokenValuation,
        uint256 _discount,
        uint256 _paymentTokenDecimals
    ) internal pure returns (uint256 paymentAmount) {
        if (_paymentTokenValuation == 0) revert PaymentTokenValuationNotValid();

        uint256 discountedOTCAmountInUSD = _otcAmountInUSD - muldiv(_otcAmountInUSD, _discount, 100e4); // 1e4 is discount decimals, 100 is discount percentage

        // Calculate payment amount
        paymentAmount = discountedOTCAmountInUSD / _paymentTokenValuation;

        if (_paymentTokenDecimals <= 18) {
            paymentAmount = paymentAmount / (10 ** (18 - _paymentTokenDecimals));
        } else {
            paymentAmount = paymentAmount * (10 ** (_paymentTokenDecimals - 18));
        }
    }

    /// @notice Emit TAP to the gauges equitably and update the net deposited amounts for each pool
    /// @dev Assume the epoch has been updated
    function _emitToGauges(uint256 _epochTAP) internal {
        SingularityPool[] memory sglPools = tOLP.getSingularityPools();
        uint256 totalWeights = tOLP.totalSingularityPoolWeights();

        uint256 len = sglPools.length;
        unchecked {
            // For each pool
            for (uint256 i; i < len; ++i) {
                uint256 currentPoolWeight = sglPools[i].poolWeight;
                uint256 quotaPerSingularity = muldiv(currentPoolWeight, _epochTAP, totalWeights);
                uint256 sglAssetID = sglPools[i].sglAssetID;
                // Emit weekly TAP to the pool
                singularityGauges[epoch][sglAssetID] = quotaPerSingularity;

                // Update net deposited amounts
                mapping(uint256 sglAssetID => int256 netAmount) storage prev = netDepositedForEpoch[epoch - 1];
                mapping(uint256 sglAssetID => int256 netAmount) storage curr = netDepositedForEpoch[epoch];

                // Pass previous epoch net amount to the next epoch
                // Expired positions are offset, check `participate()`
                curr[sglAssetID] += prev[sglAssetID];
            }
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
