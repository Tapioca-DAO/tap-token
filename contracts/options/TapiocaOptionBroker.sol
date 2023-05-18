// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "tapioca-periph/contracts/interfaces/IOracle.sol";
import "./TapiocaOptionLiquidityProvision.sol";
import "../tokens/TapOFT.sol";
import "./twAML.sol";
import "./oTAP.sol";

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
    IOracle oracle;
    bytes oracleData;
}

contract TapiocaOptionBroker is Pausable, BoringOwnable, TWAML {
    TapiocaOptionLiquidityProvision public immutable tOLP;
    bytes public tapOracleData;
    TapOFT public immutable tapOFT;
    OTAP public immutable oTAP;
    IOracle public tapOracle;

    uint256 public lastEpochUpdate; // timestamp of the last epoch update
    uint256 public epochTAPValuation; // TAP price for the current epoch
    uint256 public epoch; // Represents the number of weeks since the start of the contract

    mapping(uint256 => Participation) public participants; // tOLPTokenID => Participation
    mapping(uint256 => mapping(uint256 => bool)) public oTAPCalls; // oTAPTokenID => epoch => hasExercised

    mapping(uint256 => mapping(uint256 => uint256)) public singularityGauges; // epoch => sglAssetId => availableTAP

    mapping(ERC20 => PaymentTokenOracle) public paymentTokens; // Token address => PaymentTokenOracle
    address public paymentTokenBeneficiary; // Where to collect the payment tokens

    /// ===== TWAML ======
    mapping(uint256 => TWAMLPool) public twAML; // sglAssetId => twAMLPool

    uint256 constant MIN_WEIGHT_FACTOR = 10; // In BPS, 0.1%
    uint256 constant dMAX = 50 * 1e4; // 5% - 50% discount
    uint256 constant dMIN = 5 * 1e4;
    uint256 constant WEEK = 7 days;

    /// =====-------======
    constructor(
        address _tOLP,
        address _oTAP,
        address _tapOFT,
        address _paymentTokenBeneficiary,
        address _owner
    ) {
        paymentTokenBeneficiary = _paymentTokenBeneficiary;
        tOLP = TapiocaOptionLiquidityProvision(_tOLP);
        tapOFT = TapOFT(_tapOFT);
        oTAP = OTAP(_oTAP);
        owner = _owner;
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(
        uint256 indexed epoch,
        uint256 indexed sglAssetID,
        uint256 totalDeposited,
        LockPosition lock,
        uint256 discount
    );
    event AMLDivergence(
        uint256 indexed epoch,
        uint256 indexed cumulative,
        uint256 indexed averageMagnitude,
        uint256 totalParticipants
    );
    event ExerciseOption(
        uint256 indexed epoch,
        address indexed to,
        ERC20 indexed paymentToken,
        uint256 oTapTokenID,
        uint256 amount
    );
    event NewEpoch(
        uint256 indexed epoch,
        uint256 extractedTAP,
        uint256 epochTAPValuation
    );
    event ExitPosition(
        uint256 indexed epoch,
        uint256 indexed tokenId,
        uint256 amount
    );
    event SetPaymentToken(ERC20 paymentToken, IOracle oracle, bytes oracleData);
    event SetTapOracle(IOracle oracle, bytes oracleData);

    // ==========
    //    READ
    // ==========

    /// @notice Returns the details of an OTC deal for a given oTAP token ID and a payment token.
    ///         The oracle uses the last peeked value, and not the latest one, so the payment amount may be different.
    /// @param _oTAPTokenID The oTAP token ID
    /// @param _paymentToken The payment token
    /// @param _tapAmount The amount of TAP to be exchanged. If 0 it will use the full amount of TAP eligible for the deal
    /// @return eligibleTapAmount The amount of TAP eligible for the deal
    /// @return paymentTokenAmount The amount of payment tokens required for the deal
    function getOTCDealDetails(
        uint256 _oTAPTokenID,
        ERC20 _paymentToken,
        uint256 _tapAmount
    )
        external
        view
        returns (uint256 eligibleTapAmount, uint256 paymentTokenAmount)
    {
        // Load data
        (, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        (bool isPositionActive, LockPosition memory tOLPLockPosition) = tOLP
            .getLock(oTAPPosition.tOLP);

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[
            _paymentToken
        ];

        // Check requirements
        require(
            paymentTokenOracle.oracle != IOracle(address(0)),
            "TapiocaOptionBroker: Payment token not supported"
        );
        require(
            oTAPCalls[_oTAPTokenID][cachedEpoch] == false,
            "TapiocaOptionBroker: Already exercised"
        );
        require(isPositionActive, "TapiocaOptionBroker: Option expired");

        // Get eligible OTC amount
        uint256 gaugeTotalForEpoch = singularityGauges[cachedEpoch][
            tOLPLockPosition.sglAssetID
        ];
        eligibleTapAmount = muldiv(
            tOLPLockPosition.amount,
            gaugeTotalForEpoch,
            tOLP.getTotalPoolDeposited(tOLPLockPosition.sglAssetID)
        );

        // Get TAP valuation
        uint256 otcAmountInUSD = (
            _tapAmount == 0 ? eligibleTapAmount : _tapAmount
        ) * epochTAPValuation; // Divided by TAP decimals
        // Get payment token valuation
        (, uint256 paymentTokenValuation) = paymentTokenOracle.oracle.peek(
            paymentTokenOracle.oracleData
        );
        // Get payment token amount
        paymentTokenAmount = _getDiscountedPaymentAmount(
            otcAmountInUSD,
            paymentTokenValuation,
            oTAPPosition.discount,
            _paymentToken.decimals()
        );
    }

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in twAMl voting and mint an oTAP position
    /// @param _tOLPTokenID The tokenId of the tOLP position
    function participate(
        uint256 _tOLPTokenID
    ) external returns (uint256 oTAPTokenID) {
        // Compute option parameters
        (bool isPositionActive, LockPosition memory lock) = tOLP.getLock(
            _tOLPTokenID
        );
        require(
            isPositionActive,
            "TapiocaOptionBroker: Position is not active"
        );

        TWAMLPool memory pool = twAML[lock.sglAssetID];

        require(
            tOLP.isApprovedOrOwner(msg.sender, _tOLPTokenID),
            "TapiocaOptionBroker: Not approved or owner"
        );

        // Transfer tOLP position to this contract
        tOLP.transferFrom(msg.sender, address(this), _tOLPTokenID);

        uint256 magnitude = computeMagnitude(
            uint256(lock.lockDuration),
            pool.cumulative
        );
        bool divergenceForce;
        uint256 target = computeTarget(dMIN, dMAX, magnitude, pool.cumulative);

        // Participate in twAMl voting
        bool hasVotingPower = lock.amount >=
            computeMinWeight(pool.totalDeposited, MIN_WEIGHT_FACTOR);
        if (hasVotingPower) {
            pool.totalParticipants++; // Save participation
            pool.averageMagnitude =
                (pool.averageMagnitude + magnitude) /
                pool.totalParticipants; // compute new average magnitude

            // Compute and save new cumulative
            divergenceForce = lock.lockDuration > pool.cumulative;
            if (divergenceForce) {
                pool.cumulative += pool.averageMagnitude;
            } else {
                if (pool.cumulative > pool.averageMagnitude) {
                    pool.cumulative -= pool.averageMagnitude;
                } else {
                    pool.cumulative = 0;
                }
            }

            // Save new weight
            pool.totalDeposited += lock.amount;

            twAML[lock.sglAssetID] = pool; // Save twAML participation
            emit AMLDivergence(
                epoch,
                pool.cumulative,
                pool.averageMagnitude,
                pool.totalParticipants
            ); // Register new voting power event
        }
        // Save twAML participation
        participants[_tOLPTokenID] = Participation(
            hasVotingPower,
            divergenceForce,
            pool.averageMagnitude
        );

        // Mint oTAP position
        oTAPTokenID = oTAP.mint(
            msg.sender,
            lock.lockTime + lock.lockDuration,
            uint128(target),
            _tOLPTokenID
        );
        emit Participate(
            epoch,
            lock.sglAssetID,
            pool.totalDeposited,
            lock,
            target
        );
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    /// @param _oTAPTokenID The tokenId of the oTAP position
    function exitPosition(uint256 _oTAPTokenID) external {
        require(
            oTAP.exists(_oTAPTokenID),
            "TapiocaOptionBroker: oTAP position does not exist"
        );

        // Load data
        (, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        (, LockPosition memory lock) = tOLP.getLock(oTAPPosition.tOLP);

        require(
            block.timestamp >= lock.lockTime + lock.lockDuration,
            "TapiocaOptionBroker: Lock not expired"
        );

        Participation memory participation = participants[oTAPPosition.tOLP];

        // Remove participation
        if (participation.hasVotingPower) {
            TWAMLPool memory pool = twAML[lock.sglAssetID];

            if (divergenceForce) {
                if (pool.cumulative > pool.averageMagnitude) {
                    pool.cumulative -= pool.averageMagnitude;
                } else {
                    pool.cumulative = 0;
                }
            } else {
                pool.cumulative += pool.averageMagnitude;
            }

            pool.totalDeposited -= lock.amount;
            pool.totalParticipants--;

            twAML[lock.sglAssetID] = pool; // Save twAML exit
            emit AMLDivergence(
                epoch,
                pool.cumulative,
                pool.averageMagnitude,
                pool.totalParticipants
            ); // Register new voting power event
        }

        // Delete participation and burn oTAP position
        address otapOwner = oTAP.ownerOf(_oTAPTokenID);
        delete participants[oTAPPosition.tOLP];
        oTAP.burn(_oTAPTokenID);

        // Transfer position back to oTAP owner
        tOLP.transferFrom(address(this), otapOwner, oTAPPosition.tOLP);

        emit ExitPosition(epoch, oTAPPosition.tOLP, lock.amount);
    }

    /// @notice Exercise an oTAP position
    /// @param _oTAPTokenID tokenId of the oTAP position, position must be active
    /// @param _paymentToken Address of the payment token to use, must be whitelisted
    /// @param _tapAmount Amount of TAP to exercise. If 0, the full amount is exercised
    function exerciseOption(
        uint256 _oTAPTokenID,
        ERC20 _paymentToken,
        uint256 _tapAmount
    ) external {
        // Load data
        (, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        (bool isPositionActive, LockPosition memory tOLPLockPosition) = tOLP
            .getLock(oTAPPosition.tOLP);

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[
            _paymentToken
        ];

        // Check requirements
        require(
            paymentTokenOracle.oracle != IOracle(address(0)),
            "TapiocaOptionBroker: Payment token not supported"
        );
        require(
            oTAP.isApprovedOrOwner(msg.sender, _oTAPTokenID),
            "TapiocaOptionBroker: Not approved or owner"
        );
        require(
            oTAPCalls[_oTAPTokenID][cachedEpoch] == false,
            "TapiocaOptionBroker: Already exercised"
        );
        require(isPositionActive, "TapiocaOptionBroker: Option expired");

        oTAPCalls[_oTAPTokenID][cachedEpoch] = true; // Save exercise call of the option for this epoch

        // Get eligible OTC amount
        uint256 gaugeTotalForEpoch = singularityGauges[cachedEpoch][
            tOLPLockPosition.sglAssetID
        ];
        uint256 otcTapAmount = muldiv(
            tOLPLockPosition.amount,
            gaugeTotalForEpoch,
            tOLP.getTotalPoolDeposited(tOLPLockPosition.sglAssetID)
        );
        require(
            _tapAmount <= otcTapAmount,
            "TapiocaOptionBroker: Amount exceeds eligible TAP"
        );
        uint256 chosenAmount = _tapAmount == 0 ? otcTapAmount : _tapAmount;

        // Finalize the deal
        _processOTCDeal(
            _paymentToken,
            paymentTokenOracle,
            chosenAmount,
            oTAPPosition.discount
        );

        emit ExerciseOption(
            cachedEpoch,
            msg.sender,
            _paymentToken,
            _oTAPTokenID,
            chosenAmount
        );
    }

    /// @notice Start a new epoch, extract TAP from the TapOFT contract,
    ///         emit it to the active singularities and get the price of TAP for the epoch.
    function newEpoch() external {
        require(
            block.timestamp >= lastEpochUpdate + WEEK,
            "TapiocaOptionBroker: too soon"
        );
        uint256[] memory singularities = tOLP.getSingularities();
        require(
            singularities.length > 0,
            "TapiocaOptionBroker: No active singularities"
        );

        // Update epoch info
        lastEpochUpdate = block.timestamp;
        epoch++;

        // Extract TAP
        uint256 epochTAP = tapOFT.emitForWeek();
        _emitToGauges(epochTAP);

        // Get epoch TAP valuation
        (, epochTAPValuation) = tapOracle.get(tapOracleData);
        emit NewEpoch(epoch, epochTAP, epochTAPValuation);
    }

    /// @notice Claim the Broker role of the oTAP contract
    function oTAPBrokerClaim() external {
        oTAP.brokerClaim();
    }

    // =========
    //   OWNER
    // =========

    /// @notice Set the TapOFT Oracle address and data
    /// @param _tapOracle The new TapOFT Oracle address
    /// @param _tapOracleData The new TapOFT Oracle data
    function setTapOracle(
        IOracle _tapOracle,
        bytes calldata _tapOracleData
    ) external onlyOwner {
        tapOracle = _tapOracle;
        tapOracleData = _tapOracleData;

        emit SetTapOracle(_tapOracle, _tapOracleData);
    }

    /// @notice Activate or deactivate a payment token
    /// @dev set the oracle to address(0) to deactivate, expect the same decimal precision as TAP oracle
    function setPaymentToken(
        ERC20 _paymentToken,
        IOracle _oracle,
        bytes calldata _oracleData
    ) external onlyOwner {
        paymentTokens[_paymentToken].oracle = _oracle;
        paymentTokens[_paymentToken].oracleData = _oracleData;

        emit SetPaymentToken(_paymentToken, _oracle, _oracleData);
    }

    /// @notice Set the payment token beneficiary
    /// @param _paymentTokenBeneficiary The new payment token beneficiary
    function setPaymentTokenBeneficiary(
        address _paymentTokenBeneficiary
    ) external onlyOwner {
        paymentTokenBeneficiary = _paymentTokenBeneficiary;
    }

    /// @notice Collect the payment tokens from the OTC deals
    /// @param _paymentTokens The payment tokens to collect
    function collectPaymentTokens(
        address[] calldata _paymentTokens
    ) external onlyOwner {
        require(
            paymentTokenBeneficiary != address(0),
            "TapiocaOptionBroker: Payment token beneficiary not set"
        );
        uint256 len = _paymentTokens.length;

        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                ERC20 paymentToken = ERC20(_paymentTokens[i]);
                paymentToken.transfer(
                    paymentTokenBeneficiary,
                    paymentToken.balanceOf(address(this))
                );
            }
        }
    }

    // ============
    //   INTERNAL
    // ============

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
        (, uint256 paymentTokenValuation) = _paymentTokenOracle.oracle.get(
            _paymentTokenOracle.oracleData
        );

        // Calculate payment amount and initiate the transfers
        uint256 discountedPaymentAmount = _getDiscountedPaymentAmount(
            otcAmountInUSD,
            paymentTokenValuation,
            discount,
            _paymentToken.decimals()
        );

        _paymentToken.transferFrom(
            msg.sender,
            address(this),
            discountedPaymentAmount
        );
        tapOFT.extractTAP(msg.sender, tapAmount);
    }

    /// @notice Computes the discounted payment amount for a given OTC amount in USD
    /// @param _otcAmountInUSD The OTC amount in USD, 8 decimals
    /// @param _paymentTokenValuation The payment token valuation in USD, 8 decimals
    /// @param _discount The discount in BPS
    /// @param _paymentTokenDecimals The payment token decimals
    /// @return paymentAmount The discounted payment amount
    function _getDiscountedPaymentAmount(
        uint256 _otcAmountInUSD,
        uint256 _paymentTokenValuation,
        uint256 _discount,
        uint256 _paymentTokenDecimals
    ) internal pure returns (uint256 paymentAmount) {
        // Calculate payment amount
        uint256 rawPaymentAmount = _otcAmountInUSD / _paymentTokenValuation;
        paymentAmount =
            rawPaymentAmount -
            muldiv(rawPaymentAmount, _discount, 1e6); // 1e4 is discount decimals, 100 is discount percentage
        paymentAmount = paymentAmount / (10 ** (18 - _paymentTokenDecimals));
    }

    /// @notice Emit TAP to the gauges equitably
    function _emitToGauges(uint256 _epochTAP) internal {
        SingularityPool[] memory sglPools = tOLP.getSingularityPools();
        uint256 totalWeights = tOLP.totalSingularityPoolWeights();

        uint256 len = sglPools.length;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                uint256 currentPoolWeight = sglPools[i].poolWeight;
                uint256 quotaPerSingularity = muldiv(
                    currentPoolWeight,
                    _epochTAP,
                    totalWeights
                );
                singularityGauges[epoch][
                    sglPools[i].sglAssetID
                ] = quotaPerSingularity;
            }
        }
    }
}
