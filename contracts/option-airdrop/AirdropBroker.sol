// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "tapioca-periph/contracts/interfaces/IOracle.sol";
import "../tokens/TapOFT.sol";
import "../twAML.sol";
import "./aoTAP.sol";

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

struct PaymentTokenOracle {
    IOracle oracle;
    bytes oracleData;
}

struct Phase2Info {
    uint8[4] amountsPerUsers;
    uint8[4] discountsPerUsers;
}

/// @notice More details found here https://docs.tapioca.xyz/tapioca/launch/option-airdrop
contract AirdropBroker is Pausable, BoringOwnable, FullMath {
    bytes public tapOracleData;
    TapOFT public immutable tapOFT;
    AOTAP public immutable aoTAP;
    IOracle public tapOracle;
    IERC721 public immutable PCNFT;

    uint128 public epochTAPValuation; // TAP price for the current epoch
    uint64 public lastEpochUpdate; // timestamp of the last epoch update
    uint64 public epoch; // Represents the number of weeks since the start of the contract

    mapping(ERC20 => PaymentTokenOracle) public paymentTokens; // Token address => PaymentTokenOracle
    address public paymentTokenBeneficiary; // Where to collect the payment tokens

    mapping(uint256 => mapping(uint256 => uint256)) public aoTAPCalls; // oTAPTokenID => epoch => amountExercised

    /// @notice Record of participation in phase 2 airdrop
    /// Only applicable for phase 2. To get subphases on phase 2 we do userParticipation[_user][20+roles]
    mapping(address => mapping(uint256 => bool)) public userParticipation; // user address => phase => participated

    /// =====-------======
    ///      Phase 1
    /// =====-------======

    /// @notice user address => eligible TAP amount, 0 means no eligibility
    mapping(address => uint256) public phase1Users;
    uint256 public constant PHASE_1_DISCOUNT = 50 * 1e4; // 50%

    /// =====-------======
    ///      Phase 2
    /// =====-------======

    // [OG Pearls, Sushi Frens, Tapiocans, Oysters, Cassava]
    bytes32[4] public phase2MerkleRoots; // merkle root of phase 2 airdrop
    uint8[4] public PHASE_2_AMOUNT_PER_USER = [200, 190, 200, 190];
    uint8[4] public PHASE_2_DISCOUNT_PER_USER = [50, 40, 40, 33];

    /// =====-------======
    ///      Phase 3
    /// =====-------======

    uint256 public constant PHASE_3_AMOUNT_PER_USER = 714;
    uint256 public constant PHASE_3_DISCOUNT = 50 * 1e4;

    /// =====-------======
    ///      Phase 4
    /// =====-------======

    /// @notice user address => eligible TAP amount, 0 means no eligibility
    mapping(address => uint256) public phase4Users;
    uint256 public constant PHASE_4_DISCOUNT = 33 * 1e4;

    uint256 public constant EPOCH_DURATION = 2 days;

    /// =====-------======
    constructor(
        address _aoTAP,
        address _tapOFT,
        address _pcnft,
        address _paymentTokenBeneficiary,
        address _owner
    ) {
        paymentTokenBeneficiary = _paymentTokenBeneficiary;
        tapOFT = TapOFT(_tapOFT);
        aoTAP = AOTAP(_aoTAP);
        PCNFT = IERC721(_pcnft);
        owner = _owner;
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(uint256 indexed epoch, uint256 aoTAPTokenID);
    event ExerciseOption(
        uint256 indexed epoch,
        address indexed to,
        ERC20 indexed paymentToken,
        uint256 aoTapTokenID,
        uint256 amount
    );
    event NewEpoch(uint256 indexed epoch, uint256 epochTAPValuation);

    event SetPaymentToken(ERC20 paymentToken, IOracle oracle, bytes oracleData);
    event SetTapOracle(IOracle oracle, bytes oracleData);

    // ==========
    //    READ
    // ==========

    /// @notice Returns the details of an OTC deal for a given oTAP token ID and a payment token.
    ///         The oracle uses the last peeked value, and not the latest one, so the payment amount may be different.
    /// @param _aoTAPTokenID The aoTAP token ID
    /// @param _paymentToken The payment token
    /// @param _tapAmount The amount of TAP to be exchanged. If 0 it will use the full amount of TAP eligible for the deal
    /// @return eligibleTapAmount The amount of TAP eligible for the deal
    /// @return paymentTokenAmount The amount of payment tokens required for the deal
    /// @return tapAmount The amount of TAP to be exchanged

    function getOTCDealDetails(
        uint256 _aoTAPTokenID,
        ERC20 _paymentToken,
        uint256 _tapAmount
    )
        external
        view
        returns (
            uint256 eligibleTapAmount,
            uint256 paymentTokenAmount,
            uint256 tapAmount
        )
    {
        // Load data
        (, AirdropTapOption memory aoTapOption) = aoTAP.attributes(
            _aoTAPTokenID
        );
        require(aoTapOption.expiry > block.timestamp, "adb: Option expired");

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[
            _paymentToken
        ];

        // Check requirements
        require(
            paymentTokenOracle.oracle != IOracle(address(0)),
            "adb: Payment token not supported"
        );

        eligibleTapAmount = aoTapOption.amount;
        eligibleTapAmount -= aoTAPCalls[_aoTAPTokenID][cachedEpoch]; // Subtract already exercised amount
        require(eligibleTapAmount >= _tapAmount, "adb: Too high");

        tapAmount = _tapAmount == 0 ? eligibleTapAmount : _tapAmount;
        require(tapAmount >= 1e18, "adb: Too low");
        // Get TAP valuation
        uint256 otcAmountInUSD = tapAmount * epochTAPValuation; // Divided by TAP decimals
        // Get payment token valuation
        (, uint256 paymentTokenValuation) = paymentTokenOracle.oracle.peek(
            paymentTokenOracle.oracleData
        );
        // Get payment token amount
        paymentTokenAmount = _getDiscountedPaymentAmount(
            otcAmountInUSD,
            paymentTokenValuation,
            aoTapOption.discount,
            _paymentToken.decimals()
        );
    }

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in the airdrop
    /// @param _data The data to be used for the participation, varies by phases
    function participate(
        bytes calldata _data
    ) external returns (uint256 aoTAPTokenID) {
        uint256 cachedEpoch = epoch;
        require(cachedEpoch > 0, "adb: Airdrop not started");
        require(cachedEpoch <= 4, "adb: Airdrop ended");

        // Phase 1
        if (cachedEpoch == 1) {
            aoTAPTokenID = _participatePhase1();
        } else if (cachedEpoch == 2) {
            aoTAPTokenID = _participatePhase2(_data); // _data = (uint256 role, bytes32[] _merkleProof)
        } else if (cachedEpoch == 3) {
            aoTAPTokenID = _participatePhase3(_data); // _data = (uint256 _tokenID)
        } else if (cachedEpoch == 4) {
            aoTAPTokenID = _participatePhase4();
        }

        emit Participate(cachedEpoch, aoTAPTokenID);
    }

    /// @notice Exercise an aoTAP position
    /// @param _aoTAPTokenID tokenId of the aoTAP position, position must be active
    /// @param _paymentToken Address of the payment token to use, must be whitelisted
    /// @param _tapAmount Amount of TAP to exercise. If 0, the full amount is exercised
    function exerciseOption(
        uint256 _aoTAPTokenID,
        ERC20 _paymentToken,
        uint256 _tapAmount
    ) external {
        // Load data
        (, AirdropTapOption memory aoTapOption) = aoTAP.attributes(
            _aoTAPTokenID
        );
        require(aoTapOption.expiry > block.timestamp, "adb: Option expired");

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[
            _paymentToken
        ];

        // Check requirements
        require(
            paymentTokenOracle.oracle != IOracle(address(0)),
            "adb: Payment token not supported"
        );
        require(
            aoTAP.isApprovedOrOwner(msg.sender, _aoTAPTokenID),
            "adb: Not approved or owner"
        );

        // Get eligible OTC amount

        uint256 eligibleTapAmount = aoTapOption.amount;
        eligibleTapAmount -= aoTAPCalls[_aoTAPTokenID][cachedEpoch]; // Subtract already exercised amount
        require(eligibleTapAmount >= _tapAmount, "adb: Too high");

        uint256 chosenAmount = _tapAmount == 0 ? eligibleTapAmount : _tapAmount;
        require(chosenAmount >= 1e18, "adb: Too low");
        aoTAPCalls[_aoTAPTokenID][cachedEpoch] += chosenAmount; // Adds up exercised amount to current epoch

        // Finalize the deal
        _processOTCDeal(
            _paymentToken,
            paymentTokenOracle,
            chosenAmount,
            aoTapOption.discount
        );

        emit ExerciseOption(
            cachedEpoch,
            msg.sender,
            _paymentToken,
            _aoTAPTokenID,
            chosenAmount
        );
    }

    /// @notice Start a new epoch, extract TAP from the TapOFT contract,
    ///         emit it to the active singularities and get the price of TAP for the epoch.
    function newEpoch() external {
        require(
            block.timestamp >= lastEpochUpdate + EPOCH_DURATION,
            "adb: too soon"
        );

        // Update epoch info
        lastEpochUpdate = uint64(block.timestamp);
        epoch++;

        // Get epoch TAP valuation
        (, uint256 _epochTAPValuation) = tapOracle.get(tapOracleData);
        epochTAPValuation = uint128(_epochTAPValuation);
        emit NewEpoch(epoch, epochTAPValuation);
    }

    /// @notice Claim the Broker role of the aoTAP contract
    function aoTAPBrokerClaim() external {
        aoTAP.brokerClaim();
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

    function setPhase2MerkleRoots(
        bytes32[4] calldata _merkleRoots
    ) external onlyOwner {
        phase2MerkleRoots = _merkleRoots;
    }

    function registerUserForPhase(
        uint256 _phase,
        address[] calldata _users,
        uint256[] calldata _amounts
    ) external onlyOwner {
        require(_users.length == _amounts.length, "adb: invalid input");

        if (_phase == 1) {
            for (uint256 i = 0; i < _users.length; i++) {
                phase1Users[_users[i]] = _amounts[i];
            }
        } else if (_phase == 4) {
            for (uint256 i = 0; i < _users.length; i++) {
                phase4Users[_users[i]] = _amounts[i];
            }
        }
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
            "adb: Payment token beneficiary not set"
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

    /// @notice Participate in phase 1 of the Airdrop. LBP users are given aoTAP pro-rata.
    function _participatePhase1() internal returns (uint256 oTAPTokenID) {
        uint256 _eligibleAmount = phase1Users[msg.sender];
        require(_eligibleAmount > 0, "adb: Not eligible");

        // Close eligibility
        phase1Users[msg.sender] = 0;

        // Mint aoTAP
        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        oTAPTokenID = aoTAP.mint(
            msg.sender,
            expiry,
            uint128(PHASE_1_DISCOUNT),
            _eligibleAmount
        );
    }

    /// @notice Participate in phase 2 of the Airdrop. Guild members will receive pre-defined discounts and TAP, based on role.
    /// @param _data The calldata. Needs to be the address of the user.
    /// _data = (uint256 role, bytes32[] _merkleProof). Refer to {phase2MerkleRoots} for role.
    function _participatePhase2(
        bytes calldata _data
    ) internal returns (uint256 oTAPTokenID) {
        (uint256 _role, bytes32[] memory _merkleProof) = abi.decode(
            _data,
            (uint256, bytes32[])
        );

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, phase2MerkleRoots[_role], leaf),
            "adb: Not eligible"
        );

        uint256 subPhase = 20 + _role;
        require(
            userParticipation[msg.sender][subPhase] == false,
            "adb: Already participated"
        );
        // Close eligibility
        userParticipation[msg.sender][subPhase] = true;

        // Mint aoTAP
        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        uint256 eligibleAmount = PHASE_2_AMOUNT_PER_USER[_role];
        uint128 discount = PHASE_2_DISCOUNT_PER_USER[_role];
        oTAPTokenID = aoTAP.mint(msg.sender, expiry, discount, eligibleAmount);
    }

    /// @notice Participate in phase 1 of the Airdrop. PCNFT holder will receive pre-defined discount and TAP.
    /// @param _data The calldata. Needs to be the address of the user.
    /// _data = (uint256 _tokenID)
    function _participatePhase3(
        bytes calldata _data
    ) internal returns (uint256 oTAPTokenID) {
        uint256 _tokenID = abi.decode(_data, (uint256));

        require(PCNFT.ownerOf(_tokenID) == msg.sender, "adb: Not eligible");
        require(
            userParticipation[msg.sender][3] == false,
            "adb: Already participated"
        );
        // Close eligibility
        // To avoid a potential attack vector, we cast token ID to an address instead of using _to,
        // no conflict possible, tokenID goes from 0 ... 714.
        userParticipation[address(uint160(_tokenID))][3] = true;

        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        uint256 eligibleAmount = PHASE_3_AMOUNT_PER_USER;
        uint128 discount = uint128(PHASE_3_DISCOUNT);
        oTAPTokenID = aoTAP.mint(msg.sender, expiry, discount, eligibleAmount);
    }

    /// @notice Participate in phase 4 of the Airdrop. twTAP and Cassava guild's role are given TAP pro-rata.
    function _participatePhase4() internal returns (uint256 oTAPTokenID) {
        uint256 _eligibleAmount = phase4Users[msg.sender];
        require(_eligibleAmount > 0, "adb: Not eligible");

        // Close eligibility
        phase4Users[msg.sender] = 0;

        // Mint aoTAP
        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        oTAPTokenID = aoTAP.mint(
            msg.sender,
            expiry,
            uint128(PHASE_4_DISCOUNT),
            _eligibleAmount
        );
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
        tapOFT.transfer(msg.sender, tapAmount);
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
        // Calculate payment amount
        uint256 rawPaymentAmount = _otcAmountInUSD / _paymentTokenValuation;
        paymentAmount =
            rawPaymentAmount -
            muldiv(rawPaymentAmount, _discount, 100e4); // 1e4 is discount decimals, 100 is discount percentage

        paymentAmount = paymentAmount / (10 ** (18 - _paymentTokenDecimals));
    }
}
