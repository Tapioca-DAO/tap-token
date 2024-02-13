// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Tapioca
import {ITapiocaOracle} from "tapioca-periph/interfaces/periph/ITapiocaOracle.sol";
import {TWAML, FullMath} from "contracts/options/twAML.sol"; // TODO Naming
import {TapToken} from "contracts/tokens/TapToken.sol";
import {AOTAP, AirdropTapOption} from "./aoTAP.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

struct PaymentTokenOracle {
    ITapiocaOracle oracle;
    bytes oracleData;
}

struct Phase2Info {
    uint8[4] amountsPerUsers;
    uint8[4] discountsPerUsers;
}

/**
 * @notice More details found here https://docs.tapioca.xyz/tapioca/launch/option-airdrop
 */
contract AirdropBroker is Pausable, Ownable, FullMath, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes public tapOracleData;
    ITapiocaOracle public tapOracle;
    TapToken public tapToken;
    AOTAP public immutable aoTAP;
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
    uint256 public constant PHASE_1_DISCOUNT = 500_000; //50 * 1e4; 50%

    /// =====-------======
    ///      Phase 2
    /// =====-------======

    // [OG Pearls, Tapiocans, Oysters, Cassava]
    bytes32[4] public phase2MerkleRoots; // merkle root of phase 2 airdrop
    uint8[4] public PHASE_2_AMOUNT_PER_USER = [200, 200, 190, 190];
    uint24[4] public PHASE_2_DISCOUNT_PER_USER = [500_000, 400_000, 330_000, 250_000];

    /// =====-------======
    ///      Phase 3
    /// =====-------======

    uint256 public constant PHASE_3_AMOUNT_PER_USER = 714;
    uint256 public constant PHASE_3_DISCOUNT = 500_000; //50 * 1e4; 50%

    /// =====-------======
    ///      Phase 4
    /// =====-------======

    /// @notice user address => eligible TAP amount, 0 means no eligibility
    mapping(address => uint256) public phase4Users;
    uint256 public constant PHASE_4_DISCOUNT = 330_000; //33 * 1e4;

    uint256 public EPOCH_DURATION = 2 days; // Becomes 7 days at the start of the phase 4
    uint256 public constant LAST_EPOCH = 8; // 8 epochs, 41 days long

    /// =====-------======

    error PaymentTokenNotValid();
    error OptionExpired();
    error TooHigh();
    error TooLow();
    error NotStarted();
    error Ended();
    error NotAuthorized();
    error TooSoon();
    error Failed();
    error NotValid();
    error TokenBeneficiaryNotSet();
    error NotEligible();
    error AlreadyParticipated();
    error PaymentAmountNotValid();
    error TapAmountNotValid();
    error PaymentTokenValuationNotValid();
    error TapNotSet();
    error TapOracleNotSet();

    constructor(address _aoTAP, address _pcnft, address _paymentTokenBeneficiary, address _owner) {
        paymentTokenBeneficiary = _paymentTokenBeneficiary;
        aoTAP = AOTAP(_aoTAP);
        PCNFT = IERC721(_pcnft);

        _transferOwnership(_owner);
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(uint256 indexed epoch, uint256 aoTAPTokenID);
    event ExerciseOption(
        uint256 indexed epoch, address indexed to, ERC20 indexed paymentToken, uint256 aoTapTokenID, uint256 amount
    );
    event NewEpoch(uint256 indexed epoch, uint256 epochTAPValuation);
    event SetPaymentToken(ERC20 paymentToken, ITapiocaOracle oracle, bytes oracleData);
    event SetTapOracle(ITapiocaOracle oracle, bytes oracleData);
    event Phase2MerkleRootsUpdated();

    modifier tapExists() {
        if (address(tapOracle) == address(0)) revert TapOracleNotSet();
        if (address(tapToken) == address(0)) revert TapNotSet();
        _;
    }

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

    function getOTCDealDetails(uint256 _aoTAPTokenID, ERC20 _paymentToken, uint256 _tapAmount)
        external
        view
        tapExists
        returns (uint256 eligibleTapAmount, uint256 paymentTokenAmount, uint256 tapAmount)
    {
        // Load data
        (, AirdropTapOption memory aoTapOption) = aoTAP.attributes(_aoTAPTokenID);
        if (aoTapOption.expiry < block.timestamp) revert OptionExpired();

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[_paymentToken];

        // Check requirements
        if (paymentTokenOracle.oracle == ITapiocaOracle(address(0))) {
            revert PaymentTokenNotValid();
        }

        eligibleTapAmount = aoTapOption.amount;
        eligibleTapAmount -= aoTAPCalls[_aoTAPTokenID][cachedEpoch]; // Subtract already exercised amount
        if (eligibleTapAmount < _tapAmount) revert TooHigh();

        tapAmount = _tapAmount == 0 ? eligibleTapAmount : _tapAmount;
        if (tapAmount < 1e18) revert TooLow();
        // Get TAP valuation
        uint256 otcAmountInUSD = tapAmount * epochTAPValuation; // Divided by TAP decimals
        // Get payment token valuation
        (, uint256 paymentTokenValuation) = paymentTokenOracle.oracle.peek(paymentTokenOracle.oracleData);
        // Get payment token amount
        paymentTokenAmount = _getDiscountedPaymentAmount(
            otcAmountInUSD, paymentTokenValuation, aoTapOption.discount, _paymentToken.decimals()
        );
    }

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in the airdrop
    /// @param _data The data to be used for the participation, varies by phases
    function participate(bytes calldata _data) external whenNotPaused tapExists returns (uint256 aoTAPTokenID) {
        uint256 cachedEpoch = epoch;
        if (cachedEpoch == 0) revert NotStarted();
        if (cachedEpoch > LAST_EPOCH) revert Ended();

        // Phase 1
        if (cachedEpoch == 1) {
            aoTAPTokenID = _participatePhase1();
        } else if (cachedEpoch == 2) {
            aoTAPTokenID = _participatePhase2(_data); // _data = (uint256 role, bytes32[] _merkleProof)
        } else if (cachedEpoch == 3) {
            aoTAPTokenID = _participatePhase3(_data); // _data = (uint256[] _tokenID)
        } else if (cachedEpoch >= 4) {
            aoTAPTokenID = _participatePhase4();
        }

        emit Participate(cachedEpoch, aoTAPTokenID);
    }

    /// @notice Exercise an aoTAP position
    /// @param _aoTAPTokenID tokenId of the aoTAP position, position must be active
    /// @param _paymentToken Address of the payment token to use, must be whitelisted
    /// @param _tapAmount Amount of TAP to exercise. If 0, the full amount is exercised
    function exerciseOption(uint256 _aoTAPTokenID, ERC20 _paymentToken, uint256 _tapAmount)
        external
        whenNotPaused
        tapExists
    {
        // Load data
        (, AirdropTapOption memory aoTapOption) = aoTAP.attributes(_aoTAPTokenID);
        if (aoTapOption.expiry < block.timestamp) revert OptionExpired();

        uint256 cachedEpoch = epoch;

        PaymentTokenOracle memory paymentTokenOracle = paymentTokens[_paymentToken];

        // Check requirements
        if (paymentTokenOracle.oracle == ITapiocaOracle(address(0))) {
            revert PaymentTokenNotValid();
        }
        if (!aoTAP.isApprovedOrOwner(msg.sender, _aoTAPTokenID)) {
            revert NotAuthorized();
        }

        // Get eligible OTC amount

        uint256 eligibleTapAmount = aoTapOption.amount;
        eligibleTapAmount -= aoTAPCalls[_aoTAPTokenID][cachedEpoch]; // Subtract already exercised amount
        if (eligibleTapAmount < _tapAmount) revert TooHigh();

        uint256 chosenAmount = _tapAmount == 0 ? eligibleTapAmount : _tapAmount;
        if (chosenAmount < 1e18) revert TooLow();
        aoTAPCalls[_aoTAPTokenID][cachedEpoch] += chosenAmount; // Adds up exercised amount to current epoch

        // Finalize the deal
        _processOTCDeal(_paymentToken, paymentTokenOracle, chosenAmount, aoTapOption.discount);

        emit ExerciseOption(cachedEpoch, msg.sender, _paymentToken, _aoTAPTokenID, chosenAmount);
    }

    /// @notice Start a new epoch, extract TAP from the tapToken contract,
    function newEpoch() external tapExists {
        if (block.timestamp < lastEpochUpdate + EPOCH_DURATION) {
            revert TooSoon();
        }

        // Update epoch info
        lastEpochUpdate = uint64(block.timestamp);
        epoch++;

        // At epoch 4, change the epoch duration to 7 days
        if (epoch == 4) {
            EPOCH_DURATION = 7 days;
        }

        // Get epoch TAP valuation
        (bool success, uint256 _epochTAPValuation) = tapOracle.get(tapOracleData);
        if (!success) revert Failed();
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

    function setTapToken(address payable _tapToken) external onlyOwner {
        if (address(tapToken) != address(0)) revert NotValid();
        tapToken = TapToken(_tapToken);
    }

    /// @notice Set the tapToken Oracle address and data
    /// @param _tapOracle The new tapToken Oracle address
    /// @param _tapOracleData The new tapToken Oracle data
    function setTapOracle(ITapiocaOracle _tapOracle, bytes calldata _tapOracleData) external onlyOwner {
        tapOracle = _tapOracle;
        tapOracleData = _tapOracleData;

        emit SetTapOracle(_tapOracle, _tapOracleData);
    }

    function setPhase2MerkleRoots(bytes32[4] calldata _merkleRoots) external onlyOwner {
        if (epoch >= 2) revert NotValid();
        phase2MerkleRoots = _merkleRoots;
        emit Phase2MerkleRootsUpdated();
    }

    /**
     * @notice Register users for a phase 1 or 4 with their eligible amount.
     * @param _phase The phase to register the users for
     * @param _users The users to register
     * @param _amounts The eligible amount of TAP for each user
     */
    function registerUsersForPhase(uint256 _phase, address[] calldata _users, uint256[] calldata _amounts)
        external
        onlyOwner
    {
        if (_users.length != _amounts.length) revert NotValid();

        if (_phase == 1) {
            if (epoch >= 1) revert NotValid();
            for (uint256 i; i < _users.length; i++) {
                phase1Users[_users[i]] = _amounts[i];
            }
        }
        /// @dev We want to be able to set phase 4 users in the future on subsequent epochs
        else if (_phase == 4) {
            for (uint256 i; i < _users.length; i++) {
                phase4Users[_users[i]] = _amounts[i];
            }
        }
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
        if (paymentTokenBeneficiary == address(0)) {
            revert TokenBeneficiaryNotSet();
        }
        uint256 len = _paymentTokens.length;

        unchecked {
            for (uint256 i; i < len; ++i) {
                IERC20 paymentToken = IERC20(_paymentTokens[i]);
                paymentToken.safeTransfer(paymentTokenBeneficiary, paymentToken.balanceOf(address(this)));
            }
        }
    }

    /// @notice Recover the unclaimed TAP from the contract.
    /// Should occur after the end of the airdrop, which is 8 epochs, or 41 days long.
    function daoRecoverTAP() external onlyOwner {
        if (epoch <= LAST_EPOCH) revert TooSoon();

        tapToken.transfer(msg.sender, tapToken.balanceOf(address(this)));
    }

    /**
     * @notice Un/Pauses this contract.
     */
    function setPause(bool _pauseState) external onlyOwner {
        if (_pauseState) {
            _pause();
        } else {
            _unpause();
        }
    }

    // ============
    //   INTERNAL
    // ============

    /// @notice Participate in phase 1 of the Airdrop. LBP users are given aoTAP pro-rata.
    function _participatePhase1() internal returns (uint256 oTAPTokenID) {
        uint256 _eligibleAmount = phase1Users[msg.sender];
        if (_eligibleAmount == 0) revert NotEligible();

        // Close eligibility
        phase1Users[msg.sender] = 0;

        // Mint aoTAP
        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        oTAPTokenID = aoTAP.mint(msg.sender, expiry, uint128(PHASE_1_DISCOUNT), _eligibleAmount);
    }

    /// @notice Participate in phase 2 of the Airdrop. Guild members will receive pre-defined discounts and TAP, based on role.
    /// @param _data The calldata. Needs to be the address of the user.
    /// _data = (uint256 role, bytes32[] _merkleProof). Refer to {phase2MerkleRoots} for role.
    function _participatePhase2(bytes calldata _data) internal returns (uint256 oTAPTokenID) {
        (uint256 _role, bytes32[] memory _merkleProof) = abi.decode(_data, (uint256, bytes32[]));

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(_merkleProof, phase2MerkleRoots[_role], leaf)) {
            revert NotEligible();
        }

        uint256 subPhase = 20 + _role;
        if (userParticipation[msg.sender][subPhase]) {
            revert AlreadyParticipated();
        }
        // Close eligibility
        userParticipation[msg.sender][subPhase] = true;

        // Mint aoTAP
        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        uint256 eligibleAmount = uint256(PHASE_2_AMOUNT_PER_USER[_role]) * 1e18;
        uint128 discount = uint128(PHASE_2_DISCOUNT_PER_USER[_role]);
        oTAPTokenID = aoTAP.mint(msg.sender, expiry, discount, eligibleAmount);
    }

    /// @notice Participate in phase 3 of the Airdrop. PCNFT holder will receive pre-defined discount and TAP.
    /// @param _data The calldata. Needs to be an array of PCNFT tokenIDs.
    /// _data = (uint256 PCNFT tokenID[])
    function _participatePhase3(bytes calldata _data) internal returns (uint256 oTAPTokenID) {
        uint256[] memory _tokenIDs = abi.decode(_data, (uint256[]));

        uint256 arrLen = _tokenIDs.length;
        address tokenIDToAddress;
        for (uint256 i; i < arrLen;) {
            if (PCNFT.ownerOf(_tokenIDs[i]) != msg.sender) revert NotEligible();

            // To avoid collision, we cast token ID to an address,
            // no conflict possible, tokenID goes from 0 ... 714.
            tokenIDToAddress = address(uint160(_tokenIDs[i]));
            if (userParticipation[tokenIDToAddress][3]) {
                revert AlreadyParticipated();
            }

            // Close eligibility
            userParticipation[tokenIDToAddress][3] = true;

            unchecked {
                ++i;
            }
        }

        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        uint256 eligibleAmount = arrLen * PHASE_3_AMOUNT_PER_USER * 1e18; // Phase 3 amount multiplied the number of PCNFTs
        uint128 discount = uint128(PHASE_3_DISCOUNT);
        oTAPTokenID = aoTAP.mint(msg.sender, expiry, discount, eligibleAmount);
    }

    /// @notice Participate in phase 4 of the Airdrop. twTAP and Cassava guild's role are given TAP pro-rata.
    function _participatePhase4() internal returns (uint256 oTAPTokenID) {
        uint256 _eligibleAmount = phase4Users[msg.sender];
        if (_eligibleAmount == 0) revert NotEligible();

        // Close eligibility
        phase4Users[msg.sender] = 0;

        // Mint aoTAP
        uint128 expiry = uint128(lastEpochUpdate + EPOCH_DURATION); // Set expiry to the end of the epoch
        oTAPTokenID = aoTAP.mint(msg.sender, expiry, uint128(PHASE_4_DISCOUNT), _eligibleAmount);
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
        if (tapAmount == 0) revert TapAmountNotValid();

        // Get TAP valuation
        uint256 otcAmountInUSD = tapAmount * epochTAPValuation;

        // Get payment token valuation
        (bool success, uint256 paymentTokenValuation) = _paymentTokenOracle.oracle.get(_paymentTokenOracle.oracleData);
        if (!success) revert Failed();

        // Calculate payment amount and initiate the transfers
        uint256 discountedPaymentAmount =
            _getDiscountedPaymentAmount(otcAmountInUSD, paymentTokenValuation, discount, _paymentToken.decimals());
        if (discountedPaymentAmount == 0) revert PaymentAmountNotValid();

        uint256 balBefore = _paymentToken.balanceOf(address(this));
        IERC20(address(_paymentToken)).safeTransferFrom(msg.sender, address(this), discountedPaymentAmount);
        uint256 balAfter = _paymentToken.balanceOf(address(this));
        if (balAfter - balBefore != discountedPaymentAmount) revert Failed();

        tapToken.transfer(msg.sender, tapAmount);
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
        // Calculate payment amount
        uint256 rawPaymentAmount = _otcAmountInUSD / _paymentTokenValuation;
        paymentAmount = rawPaymentAmount - muldiv(rawPaymentAmount, _discount, 100e4); // 1e4 is discount decimals, 100 is discount percentage

        paymentAmount = paymentAmount / (10 ** (18 - _paymentTokenDecimals));
    }
}
