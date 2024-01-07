// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {ExecutorOptions} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/ExecutorOptions.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {TapOFTExtExec} from "./extensions/TapOFTExtExec.sol";
import {TapOFTMsgCoder} from "./TapOFTMsgCoder.sol";
import {TwTAP} from "../../governance/twTAP.sol";

import "forge-std/console.sol";

// import {TwTAP} from "../../governance/twTAP.sol";

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

contract BaseTapOFTv2 is OFT {
    using BytesLib for bytes;
    using SafeERC20 for IERC20;
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    uint16 public constant PT_APPROVALS = 500; // Use for ERC20Permit approvals
    uint16 public constant PT_LOCK_TWTAP = 870;
    uint16 public constant PT_UNLOCK_TWTAP = 871;
    uint16 public constant PT_CLAIM_REWARDS = 872;

    /// @dev Can't be set as constructor params because TwTAP is deployed after TapOFTv2. TwTAP constructor needs TapOFT as param.
    TwTAP public twTap;

    /// @dev Used to execute certain extern calls from the TapOFTv2 contract, such as ERC20Permit approvals.
    TapOFTExtExec public tapOFTExtExec;

    error OnlyHostChain(); // Can execute an action only on host chain
    error InvalidMsgType(uint16 msgType); // Triggered if the msgType is invalid on an `_lzCompose`.
    error InvalidMsgIndex(uint16 msgIndex, uint16 expectedIndex); // The msgIndex does not follow the sequence of indexes in the `_tapComposeMsg`
    error InvalidExtraOptionsIndex(uint16 msgIndex, uint16 expectedIndex); // The option index does not follow the sequence of indexes in the `_tapComposeMsg`

    constructor(
        address _endpoint,
        address _owner
    ) OFT("TAP", "TAP", _endpoint, _owner) {
        tapOFTExtExec = new TapOFTExtExec();
    }

    /**
     * @notice set the twTAP address, can be done only once.
     */
    function setTwTAP(address _twTap) external virtual {}

    /**
     * @dev Slightly modified version of the OFT quoteSend() operation. Includes a `_msgType` parameter.
     * The `_buildMsgAndOptionsByType()` appends the packet type to the message.
     * @notice Provides a quote for the send() operation.
     * @param _sendParam The parameters for the send() operation.
     * @param _extraOptions Additional options supplied by the caller to be used in the LayerZero message.
     * @param _payInLzToken Flag indicating whether the caller is paying in the LZ token.
     * @param _composeMsg The composed message for the send() operation.
     * @dev _oftCmd The OFT command to be executed.
     * @return msgFee The calculated LayerZero messaging fee from the send() operation.
     *
     * @dev MessagingFee: LayerZero msg fee
     *  - nativeFee: The native fee.
     *  - lzTokenFee: The lzToken fee.
     */
    function quoteSendPacket(
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        bool _payInLzToken,
        bytes calldata _composeMsg,
        bytes calldata /*_oftCmd*/ // @dev unused in the default implementation.
    ) external view virtual returns (MessagingFee memory msgFee) {
        // @dev mock the amount to credit, this is the same operation used in the send().
        // The quote is as similar as possible to the actual send() operation.
        (, uint256 amountToCreditLD) = _debitView(
            _sendParam.amountToSendLD,
            _sendParam.minAmountToCreditLD,
            _sendParam.dstEid
        );

        // @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildOFTMsgAndOptions(
            _sendParam,
            _extraOptions,
            _composeMsg,
            amountToCreditLD
        );

        // @dev Calculates the LayerZero fee for the send() operation.
        return _quote(_sendParam.dstEid, message, options, _payInLzToken);
    }

    /**
     * @notice Build an OFT message and option. The message contain OFT related info such as the amount to credit and the recipient.
     * It also contains the `_composeMsg`, which is 1 or more TAP specific messages. See `_buildTapMsgAndOptions()`.
     * The option is an aggregation of the OFT message as well as the TAP messages.
     *
     * @param _sendParam: The parameters for the send operation.
     *      - dstEid::uint32: Destination endpoint ID.
     *      - to::bytes32: Recipient address.
     *      - amountToSendLD::uint256: Amount to send in local decimals.
     *      - minAmountToCreditLD::uint256: Minimum amount to credit in local decimals.
     * @param _extraOptions Additional options for the send() operation. If `_composeMsg` not empty, the `_extraOptions` should also contain the aggregation of its options.
     * @param _composeMsg The composed message for the send() operation. Is a combination of 1 or more TAP specific messages.
     * @param _amountToCreditLD The amount to credit in local decimals.
     *
     * @return message The encoded message.
     * @return options The combined LZ msgType + `_extraOptions` options.
     */
    function _buildOFTMsgAndOptions(
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        bytes calldata _composeMsg,
        uint256 _amountToCreditLD
    ) internal view returns (bytes memory message, bytes memory options) {
        bool hasCompose;

        // @dev This generated message has the msg.sender encoded into the payload so the remote knows who the caller is.
        // @dev NOTE the returned message will append `msg.sender` only if the message is composed.
        // If it's the case, it'll add the `address(msg.sender)` at the `amountToCredit` offset.
        (message, hasCompose) = OFTMsgCodec.encode(
            _sendParam.to,
            _toSD(_amountToCreditLD),
            // @dev Must be include a non empty bytes if you want to compose, EVEN if you don't need it on the remote.
            // EVEN if you don't require an arbitrary payload to be sent... eg. '0x01'
            _composeMsg
        );
        // @dev Change the msg type depending if its composed or not.
        uint16 _msgType = hasCompose ? SEND_AND_CALL : SEND;
        // @dev Combine the callers _extraOptions with the enforced options via the OAppOptionsType3.
        options = combineOptions(_sendParam.dstEid, _msgType, _extraOptions);

        // @dev Optionally inspect the message and options depending if the OApp owner has set a msg inspector.
        // @dev If it fails inspection, needs to revert in the implementation. ie. does not rely on return boolean
        if (msgInspector != address(0))
            IOAppMsgInspector(msgInspector).inspect(message, options);
    }

    /**
     * @dev Internal function to build the message and options.
     *
     * @param _msg The TAP message to be encoded.
     * @param _msgType The message type, TAP custom ones, with `PT_` as a prefix.
     * @param _msgIndex The index of the current TAP compose msg.
     * @param _dstEid The destination endpoint ID.
     * @param _extraOptions Extra options for this message. Used to add extra options or aggregate previous `_tapComposedMsg` options.
     * @param _tapComposedMsg The previous TAP compose messages. Empty if this is the first message.
     *
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function _buildTapComposeMsgAndOptions(
        bytes calldata _msg,
        uint16 _msgType,
        uint16 _msgIndex,
        uint32 _dstEid,
        bytes calldata _extraOptions,
        bytes calldata _tapComposedMsg
    ) internal view returns (bytes memory message, bytes memory options) {
        _sanitizeMsgType(_msgType);
        _sanitizeMsgIndex(_msgIndex, _tapComposedMsg);

        message = TapOFTMsgCoder.encodeTapComposeMsg(
            _msgType,
            _msgIndex,
            _msg,
            _tapComposedMsg
        );

        _sanitizeExtraOptionsIndex(_msgIndex, _extraOptions);

        // @dev Combine the callers _extraOptions with the enforced options via the OAppOptionsType3.
        options = combineOptions(_dstEid, _msgType, _extraOptions);

        // @dev Optionally inspect the message and options depending if the OApp owner has set a msg inspector.
        // @dev If it fails inspection, needs to revert in the implementation. ie. does not rely on return boolean
        if (msgInspector != address(0))
            IOAppMsgInspector(msgInspector).inspect(message, options);
    }

    // TODO remove sanitization? If `_sendPacket()` is internal, then the msgType is what we expect it to be.
    /**
     * @dev Sanitizes the message type to match one of the Tapioca supported ones.
     * @param _msgType The message type, custom ones with `PT_` as a prefix.
     */
    function _sanitizeMsgType(uint16 _msgType) internal pure {
        if (
            // Tapioca msg types
            _msgType == PT_APPROVALS ||
            _msgType == PT_LOCK_TWTAP ||
            _msgType == PT_UNLOCK_TWTAP ||
            _msgType == PT_CLAIM_REWARDS
        ) {
            return;
        }

        revert InvalidMsgType(_msgType);
    }

    /**
     * @dev Sanitizes the msgIndex to match the sequence of indexes in the `_tapComposeMsg`.
     *
     * @param _msgIndex The current message index.
     * @param _tapComposeMsg The previous TAP compose messages. Empty if this is the first message.
     */
    function _sanitizeMsgIndex(
        uint16 _msgIndex,
        bytes calldata _tapComposeMsg
    ) internal pure {
        // If the msgIndex is 0 and there's no composeMsg, then it's the first message.
        if (_tapComposeMsg.length == 0 && _msgIndex == 0) {
            return;
        }

        uint16 _expectedMsgIndex;
        // If there's a composeMsg, then the msgIndex must be greater than 0, and an increment of the previous msgIndex.
        if (_tapComposeMsg.length > 0) {
            // If the msgIndex is not 0, then it's not the first message. Check previous indexes.
            _expectedMsgIndex =
                TapOFTMsgCoder.decodeIndexOfTapComposeMsg(_tapComposeMsg) +
                1; // Previous index + 1

            if (_msgIndex == _expectedMsgIndex) {
                return;
            }
        }

        revert InvalidMsgIndex(_msgIndex, _expectedMsgIndex);
    }

    /**
     * @dev Sanitizes the extra options index to match the sequence of indexes in the `_tapComposeMsg`.
     * @dev Works only on a single option in the `_extraOptions`.
     *
     * Single option structure, see `OptionsBuilder.addExecutorLzComposeOption`
     * ------------------------------------------------------------- *
     * Name            | type     | start | end                      *
     * ------------------------------------------------------------- *
     * WORKER_ID       | uint16   | 0     | 2                        *
     * ------------------------------------------------------------- *
     * OPTION_LENGTH   | uint16   | 2     | 4                        *
     * ------------------------------------------------------------- *
     * OPTION_TYPE     | uint16   | 4     | 6                        *
     * ------------------------------------------------------------- *
     * INDEX           | uint16   | 6     | 8                        *
     * ------------------------------------------------------------- *
     * GAS             | uint128  | 8     | 24                       *
     * ------------------------------------------------------------- *
     * VALUE           | uint128  | 24    | 32                       *
     * ------------------------------------------------------------- *
     *
     * @param _msgIndex The current message index.
     * @param _extraOptions The extra options to be sanitized.
     */
    function _sanitizeExtraOptionsIndex(
        uint16 _msgIndex,
        bytes calldata _extraOptions
    ) internal pure {
        uint16 index = BytesLib.toUint16(_extraOptions[6:], 0);

        if (index != _msgIndex) {
            revert InvalidExtraOptionsIndex(index, _msgIndex);
        }
    }

    /**
     * @dev Internal function to return the current EID.
     */
    function _getChainId() internal view virtual returns (uint32) {}
}
