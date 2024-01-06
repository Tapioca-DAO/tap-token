// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

// LZ
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {LockTwTapPositionMsg} from "./ITapOFTv2.sol";

import "forge-std/console.sol";

library TapOFTMsgCoder {
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
     * @param _tapComposeMsg The Tap composed message.
     * @return _msg The encoded message. Empty bytes if it's the end of compose message.
     */
    function encodeTapComposeMsg(
        uint16 _msgType,
        uint16 _msgIndex,
        bytes memory _tapComposeMsg,
        bytes memory _msg
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _msgType,
                uint16(_tapComposeMsg.length),
                _msgIndex,
                _tapComposeMsg,
                _msg
            );
    }

    /**
     * @notice Decodes a TapOFTv2 composed message. Used by the TapOFTv2 receiver.
     *
     * TapOFTv2 message packet.
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
    function decodeTapComposeMsg(
        bytes memory _msg
    )
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
        msgType_ = BytesLib.toUint16(
            BytesLib.slice(_msg, 0, MSG_TYPE_OFFSET),
            0
        );
        msgLength_ = BytesLib.toUint16(
            BytesLib.slice(_msg, MSG_TYPE_OFFSET, MSG_LENGTH_OFFSET),
            0
        );

        msgIndex_ = BytesLib.toUint16(
            BytesLib.slice(_msg, MSG_LENGTH_OFFSET, MSG_INDEX_OFFSET),
            0
        );
        tapComposeMsg_ = BytesLib.slice(_msg, MSG_INDEX_OFFSET, msgLength_);

        uint256 tapComposeOffset_ = MSG_INDEX_OFFSET + msgLength_;
        nextMsg_ = BytesLib.slice(
            _msg,
            tapComposeOffset_,
            _msg.length - (tapComposeOffset_)
        );
    }

    /**
     * @notice Decodes the index of a TapOFTv2 composed message.
     *
     * @param _msg The composed message for the send() operation.
     * @return msgIndex_ The index of the current message.
     */
    function decodeIndexOfTapComposeMsg(
        bytes memory _msg
    ) internal pure returns (uint16 msgIndex_) {
        return
            BytesLib.toUint16(
                BytesLib.slice(_msg, MSG_LENGTH_OFFSET, MSG_INDEX_OFFSET),
                0
            );
    }

    /**
     * @notice Decode an OFT `_lzReceive()` message.
     *
     * LzCompose message packet.
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
    function decodeLzComposeMsg(
        bytes calldata _msg
    )
        internal
        pure
        returns (address composeSender_, bytes memory oftComposeMsg_)
    {
        composeSender_ = OFTMsgCodec.bytes32ToAddress(
            bytes32(BytesLib.slice(_msg, 0, LZ_COMPOSE_SENDER))
        );

        oftComposeMsg_ = BytesLib.slice(
            _msg,
            LZ_COMPOSE_SENDER,
            _msg.length - LZ_COMPOSE_SENDER
        );
    }

    // ***************************************
    // * Encoding & Decoding TapOFT messages *
    // ***************************************

    /**
     * @notice Encodes the message for the lockTwTapPosition() operation.
     **/
    function buildLockTwTapPositionMsg(
        LockTwTapPositionMsg memory _lockTwTapPositionMsg
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _lockTwTapPositionMsg.user,
                _lockTwTapPositionMsg.duration,
                _lockTwTapPositionMsg.amount
            );
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
    function decodeLockTwpTapDstMsg(
        bytes memory _msg
    )
        internal
        pure
        returns (LockTwTapPositionMsg memory lockTwTapPositionMsg_)
    {
        // TODO bitwise operators
        // Offsets
        uint8 userOffset_ = 20;
        uint8 durationOffset_ = 32;

        // Decoded data
        address user = BytesLib.toAddress(
            BytesLib.slice(_msg, 0, userOffset_),
            0
        );

        uint96 duration = BytesLib.toUint96(
            BytesLib.slice(_msg, userOffset_, durationOffset_),
            0
        );

        uint256 amount = BytesLib.toUint256(
            BytesLib.slice(
                _msg,
                durationOffset_,
                _msg.length - durationOffset_
            ),
            0
        );

        // Return structured data
        lockTwTapPositionMsg_ = LockTwTapPositionMsg(user, duration, amount);
    }

    /**
     *      * LzCompose message packet.
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
    function decodeExecutorLzComposeOption(
        bytes memory _options
    ) internal pure returns (address executor_) {
        return
            OFTMsgCodec.bytes32ToAddress(
                bytes32(BytesLib.slice(_options, 0, 32))
            );
    }
}
