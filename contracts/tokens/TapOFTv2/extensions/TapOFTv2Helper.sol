// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";
// External
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// Tapioca

import {
    ITapOFTv2,
    LockTwTapPositionMsg,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    UnlockTwTapPositionMsg,
    LZSendParam,
    ERC20PermitStruct,
    ERC721PermitStruct,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    ClaimTwTapRewardsMsg
} from "../ITapOFTv2.sol";
import {TapOFTMsgCoder} from "../TapOFTMsgCoder.sol";
import {TapOFTV2} from "../TapOFTV2.sol";

import "forge-std/console.sol";

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

/**
 * @notice Used to build the TAP compose messages.
 */
struct ComposeMsgData {
    uint8 index; // The index of the message.
    uint128 gas; // The gasLimit used on the compose() function in the OApp for this message.
    uint128 value; // The msg.value passed to the compose() function in the OApp for this message.
    bytes data; // The data of the message.
    bytes prevData; // The previous compose msg data, if any. Used to aggregate the compose msg data.
    bytes prevOptionsData; // The previous compose msg options data, if any. Used to aggregate  the compose msg options.
}

/**
 * @notice Used to prepare an LZ call. See `TapOFTv2Helper.prepareLzCall()`.
 */
struct PrepareLzCallData {
    uint32 dstEid; // The destination endpoint ID.
    bytes32 recipient; // The recipient address. Receiver of the OFT send if any, and refund address for the LZ send.
    uint256 amountToSendLD; // The amount to send in the OFT send. If any.
    uint256 minAmountToCreditLD; // The min amount to credit in the OFT send. If any.
    uint16 msgType; // The message type, TAP custom ones, with `PT_` as a prefix.
    ComposeMsgData composeMsgData; // The compose msg data.
    uint128 lzReceiveGas; // The gasLimit used on the lzReceive() function in the OApp.
    uint128 lzReceiveValue; // The msg.value passed to the lzReceive() function in the OApp.
}

/**
 * @notice Used to return the result of the `TapOFTv2Helper.prepareLzCall()` function.
 */
struct PrepareLzCallReturn {
    bytes composeMsg; // The composed message. Can include previous composeMsg if any.
    bytes composeOptions; // The options of the composeMsg. Single option container, not aggregated with previous composeMsgOptions.
    SendParam sendParam; // OFT basic Tx params.
    MessagingFee msgFee; // OFT msg fee, include aggregation of previous composeMsgOptions.
    LZSendParam lzSendParam; // LZ Tx params. contains multiple information for the Tapioca `sendPacket()` call.
    bytes oftMsgOptions; // OFT msg options, include aggregation of previous composeMsgOptions.
}

/**
 * @title TapOFTv2Helper
 * @author TapiocaDAO
 * @notice Used as a helper contract to build calls to the TapOFTv2 contract and view functions.
 */
contract TapOFTv2Helper {
    // LZ
    uint16 public constant SEND = 1;
    // Tapioca
    uint16 public constant PT_APPROVALS = 500;
    uint16 public constant PT_LOCK_TWTAP = 870;
    uint16 public constant PT_UNLOCK_TWTAP = 871;
    uint16 public constant PT_CLAIM_REWARDS = 872;
    uint16 public constant PT_REMOTE_TRANSFER = 700;

    error InvalidMsgType(uint16 msgType); // Triggered if the msgType is invalid on an `_lzCompose`.
    error InvalidMsgIndex(uint16 msgIndex, uint16 expectedIndex); // The msgIndex does not follow the sequence of indexes in the `_tapComposeMsg`
    error InvalidExtraOptionsIndex(uint16 msgIndex, uint16 expectedIndex); // The option index does not follow the sequence of indexes in the `_tapComposeMsg`

    /**
     * ==========================
     * ERC20 APPROVAL MSG BUILDER
     * ==========================
     */

    /**
     * @dev Helper to prepare an LZ call.
     * @return prepareLzCallReturn_ The result of the `prepareLzCall()` function. See `PrepareLzCallReturn`.
     */
    function prepareLzCall(ITapOFTv2 tapOftToken, PrepareLzCallData memory _prepareLzCallData)
        public
        view
        returns (PrepareLzCallReturn memory prepareLzCallReturn_)
    {
        SendParam memory sendParam_;
        bytes memory composeOptions_;
        bytes memory composeMsg_;
        MessagingFee memory msgFee_;
        LZSendParam memory lzSendParam_;
        bytes memory oftMsgOptions_;

        // Prepare args call
        sendParam_ = SendParam({
            dstEid: _prepareLzCallData.dstEid,
            to: _prepareLzCallData.recipient,
            amountToSendLD: _prepareLzCallData.amountToSendLD,
            minAmountToCreditLD: _prepareLzCallData.minAmountToCreditLD
        });

        // If compose call found, we get its compose options and message.
        if (_prepareLzCallData.composeMsgData.data.length > 0) {
            composeOptions_ = OptionsBuilder.addExecutorLzComposeOption(
                OptionsBuilder.newOptions(),
                _prepareLzCallData.composeMsgData.index,
                _prepareLzCallData.composeMsgData.gas,
                _prepareLzCallData.composeMsgData.value
            );

            // Build the composed message. Overwrite `composeOptions_` to be with the enforced options.
            (composeMsg_, composeOptions_) = buildTapComposeMsgAndOptions(
                tapOftToken,
                _prepareLzCallData.composeMsgData.data,
                _prepareLzCallData.msgType,
                _prepareLzCallData.composeMsgData.index,
                sendParam_.dstEid,
                composeOptions_,
                _prepareLzCallData.composeMsgData.prevData // Previous tapComposeMsg.
            );
        }

        // Append previous option container if any.
        if (_prepareLzCallData.composeMsgData.prevOptionsData.length > 0) {
            require(
                _prepareLzCallData.composeMsgData.prevOptionsData.length > 0, "_prepareLzCall: invalid prevOptionsData"
            );
            oftMsgOptions_ = _prepareLzCallData.composeMsgData.prevOptionsData;
        } else {
            // Else create a new one.
            oftMsgOptions_ = OptionsBuilder.newOptions();
        }

        // Start by appending the lzReceiveOption if lzReceiveGas or lzReceiveValue is > 0.
        if (_prepareLzCallData.lzReceiveValue > 0 || _prepareLzCallData.lzReceiveGas > 0) {
            oftMsgOptions_ = OptionsBuilder.addExecutorLzReceiveOption(
                oftMsgOptions_, _prepareLzCallData.lzReceiveGas, _prepareLzCallData.lzReceiveValue
            );
        }

        // Finally, append the new compose options if any.
        if (composeOptions_.length > 0) {
            // And append the same value passed to the `composeOptions`.
            oftMsgOptions_ = OptionsBuilder.addExecutorLzComposeOption(
                oftMsgOptions_,
                _prepareLzCallData.composeMsgData.index,
                _prepareLzCallData.composeMsgData.gas,
                _prepareLzCallData.composeMsgData.value
            );
        }

        msgFee_ = tapOftToken.quoteSendPacket(sendParam_, oftMsgOptions_, false, composeMsg_, "");

        lzSendParam_ = LZSendParam({
            sendParam: sendParam_,
            fee: msgFee_,
            extraOptions: oftMsgOptions_,
            refundAddress: address(this)
        });

        prepareLzCallReturn_ = PrepareLzCallReturn({
            composeMsg: composeMsg_,
            composeOptions: composeOptions_,
            sendParam: sendParam_,
            msgFee: msgFee_,
            lzSendParam: lzSendParam_,
            oftMsgOptions: oftMsgOptions_
        });
    }

    /// =======================
    /// Builder functions
    /// =======================

    /**
     * @notice Encodes the message for the lockTwTapPosition() operation.
     *
     */
    function buildLockTwTapPositionMsg(LockTwTapPositionMsg calldata _lockTwTapPositionMsg)
        public
        pure
        returns (bytes memory)
    {
        return TapOFTMsgCoder.buildLockTwTapPositionMsg(_lockTwTapPositionMsg);
    }

    /**
     * @notice Encode the message for the _erc20PermitApprovalReceiver() operation.
     * @param _erc20PermitApprovalMsg The ERC20 permit approval messages.
     */
    function buildPermitApprovalMsg(ERC20PermitApprovalMsg[] memory _erc20PermitApprovalMsg)
        public
        pure
        returns (bytes memory msg_)
    {
        uint256 approvalsLength = _erc20PermitApprovalMsg.length;
        for (uint256 i; i < approvalsLength;) {
            msg_ = abi.encodePacked(msg_, TapOFTMsgCoder.buildERC20PermitApprovalMsg(_erc20PermitApprovalMsg[i]));
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Encode the message for the _erc721PermitApprovalReceiver() operation.
     * @param _erc721PermitApprovalMsg The ERC721 permit approval messages.
     */
    function buildNftPermitApprovalMsg(ERC721PermitApprovalMsg[] memory _erc721PermitApprovalMsg)
        public
        pure
        returns (bytes memory msg_)
    {
        uint256 approvalsLength = _erc721PermitApprovalMsg.length;
        for (uint256 i; i < approvalsLength;) {
            msg_ = abi.encodePacked(msg_, TapOFTMsgCoder.buildERC721PermitApprovalMsg(_erc721PermitApprovalMsg[i]));
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Encodes the message for the unlockTwTapPosition() operation.
     *
     */
    function buildUnlockTwpTapPositionMsg(UnlockTwTapPositionMsg memory _unlockTwTapPositionMsg)
        public
        pure
        returns (bytes memory)
    {
        return TapOFTMsgCoder.buildUnlockTwTapPositionMsg(_unlockTwTapPositionMsg);
    }

    /**
     * @notice Encodes the message for the `remoteTransfer` operation.
     * @param _lzSendParam The LZ send param to pass on the remote chain. (B->A)
     */
    function buildRemoteTransferMsg(LZSendParam memory _lzSendParam) public pure returns (bytes memory) {
        return TapOFTMsgCoder.buildRemoteTransferMsg(_lzSendParam);
    }

    /**
     * @notice Encodes the message for the `claimTwpTapRewards` operation.
     * @dev !!! NOTE: Will get all the claimable rewards for the TwTap position.
     * The caller must ensure that the TwTap contract is approved to claim the.
     * @dev The amount field is trivial in this message as it'll be overwritten by the receiver contract.
     * Any dust amount will be sent to the user on the same chain as TwTap.
     *
     * @param _claimTwTapRewardsMsg The claim rewards message.
     *        - tokenId::uint256: The tokenId of the TwTap position to claim rewards from.
     *        - lzSendParams::LZSendParam[]: The LZ send params to pass on the remote chain. (B->A)
     */
    function buildClaimRewardsMsg(ClaimTwTapRewardsMsg memory _claimTwTapRewardsMsg)
        public
        pure
        returns (bytes memory)
    {
        return TapOFTMsgCoder.buildClaimTwTapRewards(_claimTwTapRewardsMsg);
    }

    /// =======================
    /// Compose builder functions
    /// =======================

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
    function buildTapComposeMsgAndOptions(
        ITapOFTv2 _tapOFTv2,
        bytes memory _msg,
        uint16 _msgType,
        uint16 _msgIndex,
        uint32 _dstEid,
        bytes memory _extraOptions,
        bytes memory _tapComposedMsg
    ) public view returns (bytes memory message, bytes memory options) {
        _sanitizeMsgType(_msgType);
        _sanitizeMsgIndex(_msgIndex, _tapComposedMsg);

        message = TapOFTMsgCoder.encodeTapComposeMsg(_msg, _msgType, _msgIndex, _tapComposedMsg);

        // TODO fix
        // _sanitizeExtraOptionsIndex(_msgIndex, _extraOptions);
        // @dev Combine the callers _extraOptions with the enforced options via the OAppOptionsType3.

        options = _tapOFTv2.combineOptions(_dstEid, _msgType, _extraOptions);
    }

    // TODO remove sanitization? If `_sendPacket()` is internal, then the msgType is what we expect it to be.
    /**
     * @dev Sanitizes the message type to match one of the Tapioca supported ones.
     * @param _msgType The message type, custom ones with `PT_` as a prefix.
     */
    function _sanitizeMsgType(uint16 _msgType) internal pure {
        if (
            // LZ
            _msgType == SEND
            // Tapioca msg types
            || _msgType == PT_APPROVALS || _msgType == PT_LOCK_TWTAP || _msgType == PT_UNLOCK_TWTAP
                || _msgType == PT_CLAIM_REWARDS || _msgType == PT_REMOTE_TRANSFER
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
    function _sanitizeMsgIndex(uint16 _msgIndex, bytes memory _tapComposeMsg) internal pure {
        // If the msgIndex is 0 and there's no composeMsg, then it's the first message.
        if (_tapComposeMsg.length == 0 && _msgIndex == 0) {
            return;
        }

        bytes memory nextMsg_ = _tapComposeMsg;
        uint16 lastIndex_;
        while (nextMsg_.length > 0) {
            lastIndex_ = TapOFTMsgCoder.decodeIndexOfTapComposeMsg(nextMsg_);
            nextMsg_ = TapOFTMsgCoder.decodeNextMsgOfTapCompose(nextMsg_);
        }

        // If there's a composeMsg, then the msgIndex must be greater than 0, and an increment of the last msgIndex.
        uint16 expectedMsgIndex_ = lastIndex_ + 1;
        if (_tapComposeMsg.length > 0) {
            if (_msgIndex == expectedMsgIndex_) {
                return;
            }
        }

        revert InvalidMsgIndex(_msgIndex, expectedMsgIndex_);
    }

    /**
     * @dev Sanitizes the extra options index to match the sequence of indexes in the `_tapComposeMsg`.
     * @dev Works only on a single option in the `_extraOptions`.
     *
     * @dev The options are prepend by the `OptionBuilder.newOptions()`
     * ------------------------------------------------------------- *
     * Name            | type     | start | end                      *
     * ------------------------------------------------------------- *
     * NEW_OPTION      | uint16   | 0     | 2                        *
     * ------------------------------------------------------------- *
     *
     * Single option structure, see `OptionsBuilder.addExecutorLzComposeOption`
     * ------------------------------------------------------------- *
     * Name            | type     | start | end  | comment           *
     * ------------------------------------------------------------- *
     * WORKER_ID       | uint8    | 0     | 1    |                   *
     * ------------------------------------------------------------- *
     * OPTION_LENGTH   | uint16   | 1     | 3    |                   *
     * ------------------------------------------------------------- *
     * OPTION_TYPE     | uint8    | 3     | 4    |                   *
     * ------------------------------------------------------------- *
     * INDEX           | uint16   | 4     | 6    |                   *
     * ------------------------------------------------------------- *
     * GAS             | uint128  | 6     | 22   |                   *
     * ------------------------------------------------------------- *
     * VALUE           | uint128  | 22    | 38   | Possible drop     *
     * ------------------------------------------------------------- *
     *
     *
     * @param _msgIndex The current message index.
     * @param _extraOptions The extra options to be sanitized.
     */
    // function _sanitizeExtraOptionsIndex(uint16 _msgIndex, bytes memory _extraOptions) internal view {
    //     uint16 msgLength_ = TapOFTMsgCoder.decodeLengthOfExtraOptions(_extraOptions);

    //     // If the msgIndex is 0 and there's only 1 extra option, then it's the first message.
    //     if (_msgIndex == 0) {
    //         /// 19 = OptionType (1) + Index (8) + Gas (16)
    //         if (msgLength_ == 19 && _extraOptions.length == 24) {
    //             // Case where `value` was not encoded.
    //             return;
    //         }
    //         /// 35 = OptionType (1) + Index (8) + Gas (16) + Value (16)
    //         if (msgLength_ == 35 && _extraOptions.length == 40) {
    //             // Case where `value` was encoded.
    //             return;
    //         }
    //     }

    //     // Else check for the sequence of indexes.
    //     bytes memory nextMsg_ = _extraOptions;
    //     uint16 lastIndex_;
    //     while (nextMsg_.length > 0) {
    //         lastIndex_ = TapOFTMsgCoder.decodeIndexOfExtraOptions(nextMsg_);
    //         nextMsg_ = TapOFTMsgCoder.decodeNextMsgOfExtraOptions(nextMsg_);
    //     }

    //     // If there's a composeMsg, then the msgIndex must be greater than 0, and an increment of the last msgIndex.
    //     uint16 expectedMsgIndex_ = lastIndex_ + 1;
    //     if (_extraOptions.length > 0) {
    //         if (_msgIndex == expectedMsgIndex_) {
    //             return;
    //         }
    //     }

    //     revert InvalidExtraOptionsIndex(_msgIndex, expectedMsgIndex_);
    // }
}
