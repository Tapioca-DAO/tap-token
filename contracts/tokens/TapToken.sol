// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

//LZ
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";
import {MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OAppReceiver} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppReceiver.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

// External
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

// Tapioca
import {BaseTapiocaOmnichainEngine} from "tapioca-periph/tapiocaOmnichainEngine/BaseTapiocaOmnichainEngine.sol";
import {TapiocaOmnichainSender} from "tapioca-periph/tapiocaOmnichainEngine/TapiocaOmnichainSender.sol";
import {ERC20PermitStruct, ITapToken, LZSendParam} from "tap-token/tokens/ITapToken.sol";
import {ModuleManager} from "./module/ModuleManager.sol";
import {TapTokenReceiver} from "./TapTokenReceiver.sol";
import {TwTAP} from "tap-token/governance/twTAP.sol";
import {TapTokenSender} from "./TapTokenSender.sol";
import {BaseTapToken} from "./BaseTapToken.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/// @title Tapioca OFTv2 token
/// @notice OFT compatible TAP token
/// @dev Emissions E(x)= E(x-1) - E(x-1) * D with E being total supply a x week, and D the initial decay rate
contract TapToken is BaseTapToken, ModuleManager, ERC20Permit, Pausable {
    uint256 public constant INITIAL_SUPPLY = 46_686_595 * 1e18; // Everything minus DSO
    uint256 public dso_supply = 53_313_405 * 1e18; // Emission supply for DSO

    /// @notice the a parameter used in the emission function;
    uint256 constant decay_rate = 8800000000000000; // 0.88%
    uint256 constant DECAY_RATE_DECIMAL = 1e18;

    /// @notice seconds in a week
    uint256 public immutable EPOCH_DURATION;

    /// @notice starts time for emissions
    /// @dev initialized in the constructor with block.timestamp
    uint256 public emissionsStartTime;

    /// @notice returns the amount of emitted TAP for a specific week
    /// @dev week is computed using (timestamp - emissionStartTime) / WEEK
    mapping(uint256 => uint256) public emissionForWeek;

    /// @notice returns the amount minted for a specific week
    /// @dev week is computed using (timestamp - emissionStartTime) / WEEK
    mapping(uint256 => uint256) public mintedInWeek;

    /// @notice returns the minter address
    address public minter;

    /// @notice LayerZero governance chain identifier
    uint256 public governanceEid;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice event emitted when a new minter is set
    event MinterUpdated(address _old, address _new);
    /// @notice event emitted when a new emission is called
    event Emitted(uint256 indexed week, uint256 amount);
    /// @notice event emitted when new TAP is minted
    event Minted(address indexed _by, address indexed _to, uint256 _amount);
    /// @notice event emitted when new TAP is burned
    event Burned(address indexed _from, uint256 _amount);

    error OnlyHostChain();

    // ==========
    // *ERRORS*
    // ==========
    error NotValid(); // Generic error for simple functions
    error AddressWrong();
    error SupplyNotValid(); // Initial supply is not valid
    error AllowanceNotValid();
    error OnlyMinter();
    error TwTapAlreadySet();
    error InitStarted();
    error InitNotStarted();
    error InsufficientEmissions();

    // ===========
    // *MODIFIERS*
    // ===========
    modifier onlyMinter() {
        if (msg.sender != minter) revert OnlyMinter();
        _;
    }

    modifier onlyHostChain() {
        if (_getChainId() != governanceEid) revert OnlyHostChain();
        _;
    }

    /**
     * @notice Creates a new TAP OFT type token
     * @dev The initial supply of 100M is not minted here as we have the wrap method
     *
     * Allocation:
     * ============
     * DSO: 53,313,405
     * DAO: 8m
     * Contributors: 15m
     * Early supporters: 3,686,595
     * Supporters: 12.5m
     * LBP: 5m
     * Airdrop: 2.5m
     * == 100M ==
     *
     * @param _data.epochDuration The duration of an epoch in seconds.
     * @param _data.endpoint The layer zero address endpoint deployed on the current chain.
     * @param _data.contributors Address of the  contributors. 15m TAP.
     * @param _data.earlySupporters Address of early supporters. 3,686,595 TAP.
     * @param _data.supporters Address of supporters. 12.5m TAP.
     * @param _data.lTap Address of the LBP redemption token, lTap. 5m TAP.
     * @param _data.dao Address of the DAO. 8m TAP.
     * @param _data.airdrop Address of the airdrop contract. 2.5m TAP.
     * @param _data.governanceEid Governance chain endpoint ID. Should be EID of the twTAP chain.
     * @param _data.owner Address of the conservator/owner.
     * @param _data.tapTokenSenderModule Address of the TapTokenSenderModule.
     * @param _data.tapTokenReceiverModule Address of the TapTokenReceiverModule.
     * @param _data.extExec Address of the external executor.
     */
    constructor(ITapToken.TapTokenConstructorData memory _data)
        BaseTapToken("TapToken", "TAP", _data.endpoint, _data.owner, _data.extExec, _data.pearlmit, _data.cluster)
        ERC20Permit("TAP")
    {
        if (_data.endpoint == address(0)) revert AddressWrong();
        governanceEid = _data.governanceEid;

        // Initialize modules
        if (_data.tapTokenSenderModule == address(0)) revert NotValid();
        if (_data.tapTokenReceiverModule == address(0)) revert NotValid();

        _setModule(uint8(ITapToken.Module.TapTokenSender), _data.tapTokenSenderModule);
        _setModule(uint8(ITapToken.Module.TapTokenReceiver), _data.tapTokenReceiverModule);

        if (_data.epochDuration == 0) revert NotValid();
        EPOCH_DURATION = _data.epochDuration;

        // Mint only on the governance chain
        if (_getChainId() == _data.governanceEid) {
            _mint(_data.contributors, 1e18 * 15_000_000);
            _mint(_data.earlySupporters, 1e18 * 3_686_595);
            _mint(_data.supporters, 1e18 * 12_500_000);
            _mint(_data.lTap, 1e18 * 5_000_000);
            _mint(_data.dao, 1e18 * 8_000_000);
            _mint(_data.airdrop, 1e18 * 2_500_000);
            if (totalSupply() != INITIAL_SUPPLY) revert SupplyNotValid();
        }

        _transferOwnership(_data.owner);
    }

    /// =====================
    /// Module setup
    /// =====================

    /**
     * @dev Fallback function should handle calls made by endpoint, which should go to the receiver module.
     */
    fallback() external payable {
        /// @dev Call the receiver module on fallback, assume it's gonna be called by endpoint.
        _executeModule(uint8(ITapToken.Module.TapTokenReceiver), msg.data, false);
    }

    receive() external payable {}

    /**
     * @dev Slightly modified version of the OFT _lzReceive() operation.
     * The composed message is sent to `address(this)` instead of `toAddress`.
     * @dev Internal function to handle the receive on the LayerZero endpoint.
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded message.
     * @dev _executor The address of the executor.
     * @dev _extraData Additional data.
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, // @dev unused in the default implementation.
        bytes calldata _extraData // @dev unused in the default implementation.
    ) public payable override {
        // Call the internal OApp implementation of lzReceive.
        _executeModule(
            uint8(ITapToken.Module.TapTokenReceiver),
            abi.encodeWithSelector(OAppReceiver.lzReceive.selector, _origin, _guid, _message, _executor, _extraData),
            false
        );
    }

    /**
     * @notice Execute a call to a module.
     * @dev Example on how `_data` should be encoded:
     *      - abi.encodeCall(IERC20.transfer, (to, amount));
     * @dev Use abi.encodeCall to encode the function call and its parameters with type safety.
     *
     * @param _module The module to execute.
     * @param _data The data to execute. Should be ABI encoded with the selector.
     * @param _forwardRevert If true, forward the revert message from the module.
     *
     * @return returnData The return data from the module execution, if any.
     */
    function executeModule(ITapToken.Module _module, bytes memory _data, bool _forwardRevert)
        external
        payable
        returns (bytes memory returnData)
    {
        return _executeModule(uint8(_module), _data, _forwardRevert);
    }

    /// ========================
    /// Frequently used modules
    /// ========================

    /**
     * @dev Slightly modified version of the OFT send() operation. Includes a `_msgType` parameter.
     * The `_buildMsgAndOptionsByType()` appends the packet type to the message.
     * @dev Executes the send operation.
     * @param _lzSendParam The parameters for the send operation.
     *      - _sendParam: The parameters for the send operation.
     *          - dstEid::uint32: Destination endpoint ID.
     *          - to::bytes32: Recipient address.
     *          - amountToSendLD::uint256: Amount to send in local decimals.
     *          - minAmountToCreditLD::uint256: Minimum amount to credit in local decimals.
     *      - _fee: The calculated fee for the send() operation.
     *          - nativeFee::uint256: The native fee.
     *          - lzTokenFee::uint256: The lzToken fee.
     *      - _extraOptions::bytes: Additional options for the send() operation.
     *      - refundAddress::address: The address to refund the native fee to.
     * @param _composeMsg The composed message for the send() operation. Is a combination of 1 or more TAP specific messages.
     *
     * @return msgReceipt The receipt for the send operation.
     *      - guid::bytes32: The unique identifier for the sent message.
     *      - nonce::uint64: The nonce of the sent message.
     *      - fee: The LayerZero fee incurred for the message.
     *          - nativeFee::uint256: The native fee.
     *          - lzTokenFee::uint256: The lzToken fee.
     * @return oftReceipt The OFT receipt information.
     *      - amountDebitLD::uint256: Amount of tokens ACTUALLY debited in local decimals.
     *      - amountCreditLD::uint256: Amount of tokens to be credited on the remote side.
     */
    function sendPacket(LZSendParam calldata _lzSendParam, bytes calldata _composeMsg)
        public
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        (msgReceipt, oftReceipt) = abi.decode(
            _executeModule(
                uint8(ITapToken.Module.TapTokenSender),
                abi.encodeCall(TapiocaOmnichainSender.sendPacket, (_lzSendParam, _composeMsg)),
                false
            ),
            (MessagingReceipt, OFTReceipt)
        );
    }

    /**
     * @dev see `TapiocaOmniChainSender.sendPacketFrom`
     */
    function sendPacketFrom(address _from, LZSendParam calldata _lzSendParam, bytes calldata _composeMsg)
        public
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        (msgReceipt, oftReceipt) = abi.decode(
            _executeModule(
                uint8(ITapToken.Module.TapTokenSender),
                abi.encodeCall(TapiocaOmnichainSender.sendPacketFrom, (_from, _lzSendParam, _composeMsg)),
                false
            ),
            (MessagingReceipt, OFTReceipt)
        );
    }

    /// =====================
    /// View
    /// =====================

    /**
     * @notice returns token's decimals
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the current week
     */
    function getCurrentWeek() external view returns (uint256) {
        return _timestampToWeek(block.timestamp);
    }

    /**
     * @notice Returns the current week emission
     */
    function getCurrentWeekEmission() external view returns (uint256) {
        return emissionForWeek[_timestampToWeek(block.timestamp)];
    }

    /**
     * @notice Returns the current week given a timestamp
     * @param timestamp The timestamp to use to compute the week
     */
    function timestampToWeek(uint256 timestamp) external view returns (uint256) {
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        if (timestamp < emissionsStartTime) return 0;

        return _timestampToWeek(timestamp);
    }

    /**
     * @dev Returns the hash of the struct used by the permit function.
     * @param _permitData Struct containing permit data.
     */
    function getTypedDataHash(ERC20PermitStruct calldata _permitData) public view returns (bytes32) {
        bytes32 permitTypeHash_ =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash_ = keccak256(
            abi.encode(
                permitTypeHash_,
                _permitData.owner,
                _permitData.spender,
                _permitData.value,
                _permitData.nonce,
                _permitData.deadline
            )
        );
        return _hashTypedDataV4(structHash_);
    }

    /// =====================
    /// External
    /// =====================

    /**
     * @notice Initializes the emissions.
     * @dev Can be called only once. By Minter.
     */
    function initEmissions() external onlyMinter {
        if (emissionsStartTime != 0) revert InitStarted();
        emissionsStartTime = block.timestamp;
    }

    /**
     * @notice Mint TAP for the current week. Follow the emission function.
     *
     * @param _to Address to send the minted TAP to
     * @param _amount TAP amount
     */
    function extractTAP(address _to, uint256 _amount) external onlyMinter whenNotPaused {
        if (_amount == 0) revert NotValid();
        uint256 week = _timestampToWeek(block.timestamp);

        uint256 boostedTAP = balanceOf(address(this));
        uint256 availableTap = emissionForWeek[week] - mintedInWeek[week];

        // Check if there are enough emissions for the current week for the requested amount.
        if (availableTap < _amount) {
            // If there are not enough emissions, check if the boosted TAP can cover the difference.
            if (availableTap + boostedTAP < _amount) {
                revert InsufficientEmissions();
            } else {
                // If the boosted TAP can cover the difference, mint the available TAP.
                if (availableTap > 0) {
                    _mint(_to, availableTap);
                    mintedInWeek[week] += availableTap;
                    _amount -= availableTap;
                }

                // And transfer from the boosted TAP.
                _transfer(address(this), _to, _amount);
                emit Minted(msg.sender, _to, _amount);
                return;
            }
        }

        // Mint the requested amount if there are enough emissions.
        _mint(_to, _amount);
        mintedInWeek[week] += _amount;
        emit Minted(msg.sender, _to, _amount);
    }

    /**
     * @notice Burns TAP.
     * @param _amount TAP amount.
     */
    function removeTAP(uint256 _amount) external whenNotPaused {
        _burn(msg.sender, _amount);
        emit Burned(msg.sender, _amount);
    }

    /// =====================
    /// Minter
    /// =====================

    /**
     * @notice Emit the TAP for the current week. Follow the emission function.
     * If there are unclaimed emissions from the previous week, they are added to the current week.
     * If there are some TAP in the contract, use it as boosted TAP.
     *
     * @return the emitted amount.
     */
    function emitForWeek() external onlyMinter onlyHostChain whenNotPaused returns (uint256) {
        if (emissionsStartTime == 0) revert InitNotStarted();

        uint256 week = _timestampToWeek(block.timestamp);
        if (emissionForWeek[week] > 0) return 0;

        // Compute unclaimed emission from last week and add it to the current week emission
        uint256 unclaimed;
        if (week > 0) {
            // Update DSO supply from last minted emissions
            dso_supply -= mintedInWeek[week - 1];

            // Push unclaimed emission from last week to the current week
            unclaimed = emissionForWeek[week - 1] - mintedInWeek[week - 1];
        }
        uint256 emission = _computeEmission();
        emission += unclaimed;

        emissionForWeek[week] = emission;
        emit Emitted(week, emission);

        return emission;
    }

    /// =====================
    /// Owner
    /// =====================

    /**
     * @notice Sets a new minter address.
     * @param _minter the new address
     */
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert NotValid();
        minter = _minter;
        emit MinterUpdated(minter, _minter);
    }

    /**
     * @notice set the twTAP address, can be done only once.
     */
    function setTwTAP(address _twTap) external override onlyOwner onlyHostChain {
        if (address(twTap) != address(0)) {
            revert TwTapAlreadySet();
        }
        twTap = TwTAP(_twTap);
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

    /// =====================
    /// Internal
    /// =====================

    /**
     * @dev Returns the current week given a timestamp
     * @param timestamp The timestamp to use to compute the week
     */
    function _timestampToWeek(uint256 timestamp) internal view returns (uint256) {
        return ((timestamp - emissionsStartTime) / EPOCH_DURATION);
    }

    /**
     *  @notice returns the available emissions for a given supply
     */
    function _computeEmission() internal view returns (uint256 result) {
        result = (dso_supply * decay_rate) / DECAY_RATE_DECIMAL;
    }

    /**
     * @notice Return the current chain EID.
     */
    function _getChainId() internal view override returns (uint32) {
        return IMessagingChannel(endpoint).eid();
    }
}
