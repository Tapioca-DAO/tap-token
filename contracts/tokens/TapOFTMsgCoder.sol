// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

// LZ
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {
    ITapOFTv2,
    LockTwTapPositionMsg,
    UnlockTwTapPositionMsg,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    LZSendParam,
    ClaimTwTapRewardsMsg,
    RemoteTransferMsg
} from "./ITapOFTv2.sol";

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

library TapOFTMsgCoder {
    /**
     * @dev Option Builder offsets
     *
     * @dev !!!! The options are prepend by the `OptionBuilder.newOptions()` IF it's the first option.
     *
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
     * WORKER_ID       | uint8    | 2     | 3    |                   *
     * ------------------------------------------------------------- *
     * OPTION_LENGTH   | uint16   | 3     | 5    |                   *
     * ------------------------------------------------------------- *
     * OPTION_TYPE     | uint8    | 5     | 6    |                   *
     * ------------------------------------------------------------- *
     * INDEX           | uint16   | 6     | 8    |                   *
     * ------------------------------------------------------------- *
     * GAS             | uint128  | 8     | 24   |                   *
     * ------------------------------------------------------------- *
     * VALUE           | uint128  | 24    | 40   | Can be not packed *
     * ------------------------------------------------------------- *
     */
    uint16 internal constant OP_BLDR_EXECUTOR_WORKER_ID_ = 1; // ExecutorOptions.WORKER_ID
    uint16 internal constant OP_BLDR_WORKER_ID_OFFSETS = 2;
    uint16 internal constant OP_BLDR_OPTION_LENGTH_OFFSET = 3;
    uint16 internal constant OP_BLDR_OPTIONS_TYPE_OFFSET = 5;
    uint16 internal constant OP_BLDR_INDEX_OFFSET = 6;
    uint16 internal constant OP_BLDR_GAS_OFFSET = 8;
    uint16 internal constant OP_BLDR_VALUE_OFFSET = 24;

    // LZ message offsets
    uint8 internal constant LZ_COMPOSE_SENDER = 32;

    // TapOFTv2 receiver message offsets
    uint8 internal constant MSG_TYPE_OFFSET = 2;
    uint8 internal constant MSG_LENGTH_OFFSET = 4;
    uint8 internal constant MSG_INDEX_OFFSET = 6;

    /**
     *
     * @param _msgType The message type, either custom ones with `PT_` as a prefix, or default OFT ones.
     * @param _msgIndex The index of the compose message to encode.
     * @param _msg The Tap composed message.
     * @return _tapComposedMsg The encoded message. Empty bytes if it's the end of compose message.
     */
    function encodeTapComposeMsg(bytes memory _msg, uint16 _msgType, uint16 _msgIndex, bytes memory _tapComposedMsg)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_tapComposedMsg, _msgType, uint16(_msg.length), _msgIndex, _msg);
    }

    /**
     * @notice Decodes a TapOFTv2 composed message. Used by the TapOFTv2 receiver.
     *
     *           *    TapOFTv2 message packet   *
     * ------------------------------------------------------------- *
     * Name          | type      | start | end                       *
     * ------------------------------------------------------------- *
     * msgType       | uint16    | 0     | 2                         *
     * ------------------------------------------------------------- *
     * msgLength     | uint16    | 2     | 4                         *
     * ------------------------------------------------------------- *
     * msgIndex      | uint16    | 4     | 6                         *
     * ------------------------------------------------------------- *
     * tapComposeMsg | bytes     | 6     | msglength + 6             *
     * ------------------------------------------------------------- *
     *
     * @param _msg The composed message for the send() operation.
     * @return msgType_ The message type. (TapOFT proprietary `PT_` packets or LZ defaults).
     * @return msgLength_ The length of the message.
     * @return msgIndex_ The index of the current message.
     * @return tapComposeMsg_ The TapOFT composed message, which is the actual message.
     * @return nextMsg_ The next composed message. If the message is not composed, it'll be empty.
     */
    function decodeTapComposeMsg(bytes memory _msg)
        internal
        pure
        returns (
            uint16 msgType_,
            uint16 msgLength_,
            uint16 msgIndex_,
            bytes memory tapComposeMsg_,
            bytes memory nextMsg_
        )
    {
        // TODO use bitwise operators?
        msgType_ = BytesLib.toUint16(BytesLib.slice(_msg, 0, 2), 0);
        msgLength_ = BytesLib.toUint16(BytesLib.slice(_msg, MSG_TYPE_OFFSET, 2), 0);

        msgIndex_ = BytesLib.toUint16(BytesLib.slice(_msg, MSG_LENGTH_OFFSET, 2), 0);
        tapComposeMsg_ = BytesLib.slice(_msg, MSG_INDEX_OFFSET, msgLength_);

        uint256 tapComposeOffset_ = MSG_INDEX_OFFSET + msgLength_;
        nextMsg_ = BytesLib.slice(_msg, tapComposeOffset_, _msg.length - (tapComposeOffset_));
    }

    /**
     * @notice Decodes the index of a TapOFTv2 composed message.
     *
     * @param _msg The composed message for the send() operation.
     * @return msgIndex_ The index of the current message.
     */
    function decodeIndexOfTapComposeMsg(bytes memory _msg) internal pure returns (uint16 msgIndex_) {
        return BytesLib.toUint16(BytesLib.slice(_msg, MSG_LENGTH_OFFSET, 2), 0);
    }

    /**
     * @notice Decodes the next message of a TapOFTv2 composed message, if any.
     * @param _msg The composed message for the send() operation.
     * @return nextMsg_ The next composed message. If the message is not composed, it'll be empty.
     */
    function decodeNextMsgOfTapCompose(bytes memory _msg) internal pure returns (bytes memory nextMsg_) {
        uint16 msgLength_ = BytesLib.toUint16(BytesLib.slice(_msg, MSG_TYPE_OFFSET, 2), 0);

        uint256 tapComposeOffset_ = MSG_INDEX_OFFSET + msgLength_;
        nextMsg_ = BytesLib.slice(_msg, tapComposeOffset_, _msg.length - (tapComposeOffset_));
    }

    /**
     * @dev Decode LzCompose extra options message built by `OptionBuilder.addExecutorLzComposeOption()`.
     * @dev !!! IMPORTANT !!! It only works for options built only by `OptionBuilder.addExecutorLzComposeOption()`.
     *
     * @dev !!!! The options are prepend by the `OptionBuilder.newOptions()` IF it's the first option.
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
     * WORKER_ID       | uint8    | 2     | 3    |                   *
     * ------------------------------------------------------------- *
     * OPTION_LENGTH   | uint16   | 3     | 5    |                   *
     * ------------------------------------------------------------- *
     * OPTION_TYPE     | uint8    | 5     | 6    |                   *
     * ------------------------------------------------------------- *
     * INDEX           | uint16   | 6     | 8    |                   *
     * ------------------------------------------------------------- *
     * GAS             | uint128  | 8     | 24   |                   *
     * ------------------------------------------------------------- *
     * VALUE           | uint128  | 24    | 40   | Can be not packed *
     * ------------------------------------------------------------- *
     *
     * @param _options The extra options to be sanitized.
     */
    function decodeExtraOptions(bytes memory _options)
        internal
        view
        returns (
            uint16 workerId_,
            uint16 optionLength_,
            uint16 optionType_,
            uint16 index_,
            uint128 gas_,
            uint128 value_,
            bytes memory nextMsg_
        )
    {
        workerId_ = BytesLib.toUint8(BytesLib.slice(_options, OP_BLDR_WORKER_ID_OFFSETS, 1), 0);
        console.log("workerId_", workerId_);
        // If the workerId is not decoded correctly, it means option index != 0.
        if (workerId_ != OP_BLDR_EXECUTOR_WORKER_ID_) {
            // add the new options prefix
            _options = abi.encodePacked(OptionsBuilder.newOptions(), _options);
            workerId_ = OP_BLDR_EXECUTOR_WORKER_ID_;
        }

        /// @dev Option length is not the size of the actual `_options`, but the size of the option
        /// starting from `OPTION_TYPE`.
        optionLength_ = BytesLib.toUint16(BytesLib.slice(_options, OP_BLDR_OPTION_LENGTH_OFFSET, 2), 0);
        console.log("optionLength_", optionLength_);
        optionType_ = BytesLib.toUint8(BytesLib.slice(_options, OP_BLDR_OPTIONS_TYPE_OFFSET, 1), 0);
        console.log("optionType_", optionType_);
        index_ = BytesLib.toUint16(BytesLib.slice(_options, OP_BLDR_INDEX_OFFSET, 2), 0);
        console.log("index_", index_);
        gas_ = BytesLib.toUint128(BytesLib.slice(_options, OP_BLDR_GAS_OFFSET, 16), 0);
        console.log("gas_", gas_);

        /// @dev `value_` is not encoded if it's 0, check LZ `OptionBuilder.addExecutorLzComposeOption()`
        /// and `ExecutorOptions.encodeLzComposeOption()` for more info.
        /// 19 = OptionType (1) + Index (8) + Gas (16)
        if (optionLength_ == 19) {
            uint16 nextMsgOffset = OP_BLDR_VALUE_OFFSET; // 24
            if (_options.length > nextMsgOffset) {
                nextMsg_ = BytesLib.slice(_options, nextMsgOffset, _options.length - nextMsgOffset);
            }
        }
        /// 35 = OptionType (1) + Index (8) + Gas (16) + Value (16)
        if (optionLength_ == 35) {
            value_ = BytesLib.toUint128(BytesLib.slice(_options, OP_BLDR_VALUE_OFFSET, 16), 0);

            uint16 nextMsgOffset = OP_BLDR_VALUE_OFFSET + 16; // 24 + 16 = 40
            if (_options.length > nextMsgOffset) {
                nextMsg_ = BytesLib.slice(_options, nextMsgOffset, _options.length - nextMsgOffset);
            }
        }
    }

    // /**
    //  * @notice Decodes the next message of extra options, if any.
    //  */
    // function decodeNextMsgOfExtraOptions(bytes memory _options) internal view returns (bytes memory nextMsg_) {
    //     uint16 OP_BLDR_GAS_OFFSET = 8;
    //     uint16 OP_BLDR_VALUE_OFFSET = 24;

    //     uint16 optionLength_ = decodeLengthOfExtraOptions(_options);
    //     console.log("optionLength_", optionLength_);

    //     /// @dev Value can be omitted if it's 0.
    //     /// check LZ `OptionBuilder.addExecutorLzComposeOption()` and `ExecutorOptions.encodeLzComposeOption()`
    //     /// 19 = OptionType (1) + Index (8) + Gas (16)
    //     if (optionLength_ == 19) {
    //         uint16 nextMsgOffset = OP_BLDR_GAS_OFFSET + 16; // 8 + 16 = 24
    //         console.log(nextMsgOffset);
    //         if (_options.length > nextMsgOffset) {
    //             nextMsg_ = BytesLib.slice(_options, nextMsgOffset, _options.length - nextMsgOffset);
    //         }
    //     }
    //     /// 35 = OptionType (1) + Index (8) + Gas (16) + Value (16)
    //     if (optionLength_ == 35) {
    //         uint16 nextMsgOffset = OP_BLDR_VALUE_OFFSET + 16; // 24 + 16 = 40
    //         if (_options.length > nextMsgOffset) {
    //             nextMsg_ = BytesLib.slice(_options, nextMsgOffset, _options.length - nextMsgOffset);
    //         }
    //     }
    // }

    /**
     * @notice Decode an OFT `_lzReceive()` message.
     *
     *          *    LzCompose message packet    *
     * ------------------------------------------------------------- *
     * Name           | type      | start | end                      *
     * ------------------------------------------------------------- *
     * composeSender  | bytes32   | 0     | 32                       *
     * ------------------------------------------------------------- *
     * oftComposeMsg_ | bytes     | 32    | _msg.Length              *
     * ------------------------------------------------------------- *
     *
     * @param _msg The composed message for the send() operation.
     * @return composeSender_ The address of the compose sender. (dst OApp).
     * @return oftComposeMsg_ The TapOFT composed message, which is the actual message.
     */
    function decodeLzComposeMsg(bytes calldata _msg)
        internal
        pure
        returns (address composeSender_, bytes memory oftComposeMsg_)
    {
        composeSender_ = OFTMsgCodec.bytes32ToAddress(bytes32(BytesLib.slice(_msg, 0, LZ_COMPOSE_SENDER)));

        oftComposeMsg_ = BytesLib.slice(_msg, LZ_COMPOSE_SENDER, _msg.length - LZ_COMPOSE_SENDER);
    }

    // ***************************************
    // * Encoding & Decoding TapOFT messages *
    // ***************************************

    /**
     * @notice Encodes the message for the lockTwTapPosition() operation.
     *
     */
    function buildLockTwTapPositionMsg(LockTwTapPositionMsg memory _lockTwTapPositionMsg)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(_lockTwTapPositionMsg.user, _lockTwTapPositionMsg.duration, _lockTwTapPositionMsg.amount);
    }

    /**
     * @notice Decode an encoded message for the lockTwTapPosition() operation.
     *
     * @param _msg The encoded message. see `TapOFTMsgCoder.buildLockTwTapPositionMsg()`
     * @return lockTwTapPositionMsg_ The data of the lock.
     *          - user::address: The user address.
     *          - duration::uint96: The duration of the lock.
     *          - amount::uint256: The amount to be locked.
     */
    function decodeLockTwpTapDstMsg(bytes memory _msg)
        internal
        pure
        returns (LockTwTapPositionMsg memory lockTwTapPositionMsg_)
    {
        // TODO bitwise operators
        // Offsets
        uint8 userOffset_ = 20;
        uint8 durationOffset_ = 32;

        // Decoded data
        address user = BytesLib.toAddress(BytesLib.slice(_msg, 0, userOffset_), 0);

        uint96 duration = BytesLib.toUint96(BytesLib.slice(_msg, userOffset_, durationOffset_), 0);

        uint256 amount = BytesLib.toUint256(BytesLib.slice(_msg, durationOffset_, _msg.length - durationOffset_), 0);

        // Return structured data
        lockTwTapPositionMsg_ = LockTwTapPositionMsg(user, duration, amount);
    }

    /**
     * @notice Encodes the message for the unlockTwTapPosition() operation.
     *
     */
    function buildUnlockTwTapPositionMsg(UnlockTwTapPositionMsg memory _msg) internal pure returns (bytes memory) {
        return abi.encodePacked(_msg.user, _msg.tokenId);
    }

    /**
     * @notice Decode an encoded message for the unlockTwTapPosition() operation.
     *
     * @param _msg The encoded message. see `TapOFTMsgCoder.buildUnlockTwTapPositionMsg()`
     *          - user::address: The user address.
     *          - tokenId::uint256: The tokenId of the TwTap position to unlock.
     * @return unlockTwTapPositionMsg_ The needed data.
     */
    function decodeUnlockTwTapPositionMsg(bytes memory _msg)
        internal
        pure
        returns (UnlockTwTapPositionMsg memory unlockTwTapPositionMsg_)
    {
        // Offsets
        uint8 userOffset_ = 20;

        // Decoded data
        address user_ = BytesLib.toAddress(BytesLib.slice(_msg, 0, userOffset_), 0);

        uint256 tokenId_ = BytesLib.toUint256(BytesLib.slice(_msg, userOffset_, 32), 0);

        // Return structured data
        unlockTwTapPositionMsg_ = UnlockTwTapPositionMsg(user_, tokenId_);
    }

    /**
     * @notice Encodes the message for the `remoteTransfer` operation.
     * @param _remoteTransferMsg The owner + LZ send param to pass on the remote chain. (B->A)
     */
    function buildRemoteTransferMsg(RemoteTransferMsg memory _remoteTransferMsg) internal pure returns (bytes memory) {
        return abi.encode(_remoteTransferMsg);
    }

    /**
     * @notice Decode the message for the `remoteTransfer` operation.
     * @param _msg The owner + LZ send param to pass on the remote chain. (B->A)
     */
    function decodeRemoteTransferMsg(bytes memory _msg)
        internal
        pure
        returns (RemoteTransferMsg memory remoteTransferMsg_)
    {
        return abi.decode(_msg, (RemoteTransferMsg));
    }

    /**
     * @notice Encodes the message for the `claimTwpTapRewards` operation.
     * @param _claimTwTapRewardsMsg Struct of the call.
     *        - tokenId::uint256: The tokenId of the TwTap position to claim rewards from.
     *        - lzSendParams::LZSendParam[]: The LZ send params to pass on the remote chain. (B->A)
     */
    function buildClaimTwTapRewards(ClaimTwTapRewardsMsg memory _claimTwTapRewardsMsg)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(_claimTwTapRewardsMsg);
    }

    /**
     * @notice Decode the message for the `claimTwpTapRewards` operation.
     * @param _msg The LZ send params to pass on the remote chain. (B->A)
     *        - tokenId::uint256: The tokenId of the TwTap position to claim rewards from.
     *        - lzSendParams::LZSendParam[]: The LZ send params to pass on the remote chain. (B->A)
     */
    function decodeClaimTwTapRewardsMsg(bytes memory _msg)
        internal
        pure
        returns (ClaimTwTapRewardsMsg memory claimTwTapRewardsMsg_)
    {
        return abi.decode(_msg, (ClaimTwTapRewardsMsg));
    }

    /**
     * @notice Encodes the message for the `TapOFTReceiver._erc20PermitApprovalReceiver()` operation.
     */
    function buildERC20PermitApprovalMsg(ERC20PermitApprovalMsg memory _erc20PermitApprovalMsg)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _erc20PermitApprovalMsg.token,
            _erc20PermitApprovalMsg.owner,
            _erc20PermitApprovalMsg.spender,
            _erc20PermitApprovalMsg.value,
            _erc20PermitApprovalMsg.deadline,
            _erc20PermitApprovalMsg.v,
            _erc20PermitApprovalMsg.r,
            _erc20PermitApprovalMsg.s
        );
    }

    /**
     * @notice Encodes the message for the `TapOFTReceiver._erc721PermitApprovalReceiver()` operation.
     */
    function buildERC721PermitApprovalMsg(ERC721PermitApprovalMsg memory _erc721PermitApprovalMsg)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _erc721PermitApprovalMsg.token,
            _erc721PermitApprovalMsg.spender,
            _erc721PermitApprovalMsg.tokenId,
            _erc721PermitApprovalMsg.deadline,
            _erc721PermitApprovalMsg.v,
            _erc721PermitApprovalMsg.r,
            _erc721PermitApprovalMsg.s
        );
    }

    /**
     * @notice Decodes an encoded message for the `TapOFTReceiver.erc721PermitApprovalReceiver()` operation.
     */
    function decodeArrayOfERC721PermitApprovalMsg(bytes memory _msg)
        internal
        pure
        returns (ERC721PermitApprovalMsg[] memory)
    {
        return abi.decode(_msg, (ERC721PermitApprovalMsg[]));
    }

    /**
     * @notice Decodes an encoded message for the `TapOFTReceiver.erc20PermitApprovalReceiver()` operation.
     *
     *                    *   message packet   *
     * ------------------------------------------------------------- *
     * Name          | type      | start | end                       *
     * ------------------------------------------------------------- *
     * token         | address   | 0     | 20                        *
     * ------------------------------------------------------------- *
     * owner         | address   | 20    | 40                        *
     * ------------------------------------------------------------- *
     * spender       | address   | 40    | 60                        *
     * ------------------------------------------------------------- *
     * value         | uint256   | 60    | 92                        *
     * ------------------------------------------------------------- *
     * deadline      | uint256   | 92    | 124                       *
     * ------------------------------------------------------------- *
     * v             | uint8     | 124   | 125                       *
     * ------------------------------------------------------------- *
     * r             | bytes32   | 125   | 157                       *
     * ------------------------------------------------------------- *
     * s             | bytes32   | 157   | 189                       *
     * ------------------------------------------------------------- *
     *
     * @param _msg The encoded message. see `TapOFTMsgCoder.buildERC20PermitApprovalMsg()`
     */
    struct __offsets {
        uint8 tokenOffset;
        uint8 ownerOffset;
        uint8 spenderOffset;
        uint8 valueOffset;
        uint8 deadlineOffset;
        uint8 vOffset;
        uint8 rOffset;
        uint8 sOffset;
    }

    function decodeERC20PermitApprovalMsg(bytes memory _msg)
        internal
        pure
        returns (ERC20PermitApprovalMsg memory erc20PermitApprovalMsg_)
    {
        // TODO bitwise operators ?
        __offsets memory offsets_ = __offsets({
            tokenOffset: 20,
            ownerOffset: 40,
            spenderOffset: 60,
            valueOffset: 92,
            deadlineOffset: 124,
            vOffset: 125,
            rOffset: 157,
            sOffset: 189
        });

        // Decoded data
        address token = BytesLib.toAddress(BytesLib.slice(_msg, 0, offsets_.tokenOffset), 0);

        address owner = BytesLib.toAddress(BytesLib.slice(_msg, offsets_.tokenOffset, 20), 0);

        address spender = BytesLib.toAddress(BytesLib.slice(_msg, offsets_.ownerOffset, 20), 0);

        uint256 value = BytesLib.toUint256(BytesLib.slice(_msg, offsets_.spenderOffset, 32), 0);

        uint256 deadline = BytesLib.toUint256(BytesLib.slice(_msg, offsets_.valueOffset, 32), 0);

        uint8 v = uint8(BytesLib.toUint8(BytesLib.slice(_msg, offsets_.deadlineOffset, 1), 0));

        bytes32 r = BytesLib.toBytes32(BytesLib.slice(_msg, offsets_.vOffset, 32), 0);

        bytes32 s = BytesLib.toBytes32(BytesLib.slice(_msg, offsets_.rOffset, 32), 0);

        // Return structured data
        erc20PermitApprovalMsg_ = ERC20PermitApprovalMsg(token, owner, spender, value, deadline, v, r, s);
    }

    /**
     * @dev Decode an array of encoded messages for the `TapOFTReceiver.erc20PermitApprovalReceiver()` operation.
     * @dev The message length must be a multiple of 189.
     *
     * @param _msg The encoded message. see `TapOFTMsgCoder.buildERC20PermitApprovalMsg()`
     */
    function decodeArrayOfERC20PermitApprovalMsg(bytes memory _msg)
        internal
        pure
        returns (ERC20PermitApprovalMsg[] memory)
    {
        /// @dev see `this.decodeERC20PermitApprovalMsg()`, token + owner + spender + value + deadline + v + r + s length = 189.
        uint256 msgCount_ = _msg.length / 189;

        ERC20PermitApprovalMsg[] memory erc20PermitApprovalMsgs_ = new ERC20PermitApprovalMsg[](msgCount_);

        uint256 msgIndex_;
        for (uint256 i; i < msgCount_;) {
            erc20PermitApprovalMsgs_[i] = decodeERC20PermitApprovalMsg(BytesLib.slice(_msg, msgIndex_, 189));
            unchecked {
                msgIndex_ += 189;
                ++i;
            }
        }

        return erc20PermitApprovalMsgs_;
    }

    /**
     *          *    LzCompose message packet    *
     * ------------------------------------------------------------- *
     * Name           | type      | start | end                      *
     * ------------------------------------------------------------- *
     * composeSender  | bytes32   | 0     | 32                       *
     * ------------------------------------------------------------- *
     * oftComposeMsg_ | bytes     | 32    | _msg.Length              *
     * ------------------------------------------------------------- *
     *
     *
     * @param _options  The option to decompose.
     */
    function decodeExecutorLzComposeOption(bytes memory _options) internal pure returns (address executor_) {
        return OFTMsgCodec.bytes32ToAddress(bytes32(BytesLib.slice(_options, 0, 32)));
    }
}
