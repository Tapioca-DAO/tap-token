// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

// LZ
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {LockTwTapPositionMsg} from "./ITapOFTv2.sol";

library TapOFTMsgCoder {
    // TapOFTv2 receiver message offsets
    uint8 internal constant MSG_TYPE_OFFSET = 2;

    /**
     * @notice Decode an OFT receiver composed message.
     *
     * @param _msg The composed message for the send() operation.
     * @return nonce_ The nonce of the OFT message.
     * @return srcEid_ The source EID of the message.
     * @return amountReceivedLD_ The amount received in local decimals.
     * @return composeSender_ The address of the compose sender. (dst OApp).
     * @return msgType_ The message type. (TapOFT proprietary `PT_` packets).
     * @return tapComposeMsg_ The TapOFT composed message, which is the actual message.
     */
    function decodeReceiverComposeMsg(
        bytes calldata _msg
    )
        internal
        pure
        returns (
            uint64 nonce_,
            uint32 srcEid_,
            uint256 amountReceivedLD_,
            address composeSender_,
            uint16 msgType_,
            bytes memory tapComposeMsg_
        )
    {
        nonce_ = OFTComposeMsgCodec.nonce(_msg);
        srcEid_ = OFTComposeMsgCodec.srcEid(_msg);
        amountReceivedLD_ = OFTComposeMsgCodec.amountLD(_msg);
        composeSender_ = OFTComposeMsgCodec.bytes32ToAddress(
            OFTComposeMsgCodec.composeFrom(_msg)
        );

        bytes memory oftComposeMsg_ = OFTComposeMsgCodec.composeMsg(_msg);

        msgType_ = BytesLib.toUint16(
            BytesLib.slice(oftComposeMsg_, 0, MSG_TYPE_OFFSET),
            0
        );
        tapComposeMsg_ = BytesLib.slice(
            oftComposeMsg_,
            MSG_TYPE_OFFSET,
            oftComposeMsg_.length - MSG_TYPE_OFFSET
        );
    }

    // ***************************************
    // * Encoding & Decoding TapOFT messages *
    // ***************************************

    /**
     * @notice Encodes the message for the lockTwTapPosition() operation.
     **/
    function buildLockTwTapPositionMsg(
        LockTwTapPositionMsg calldata _lockTwTapPositionMsg
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _lockTwTapPositionMsg.user,
                _lockTwTapPositionMsg.duration
            );
    }

    /**
     * @notice Decode a composed message for the lockTwTapPosition() operation.
     *
     * @param _composeMsg The composed message for the send() operation.
     * @return lockTwTapPositionMsg The data of the lock.
     *          - user::address: The user address.
     *          - duration::uint256: The duration of the lock.
     */
    function decodeLockTwpTapDstMsg(
        bytes memory _composeMsg
    ) internal pure returns (LockTwTapPositionMsg memory lockTwTapPositionMsg) {
        // Offsets
        uint8 userOffset_ = 20;
        address user = BytesLib.toAddress(
            BytesLib.slice(_composeMsg, 0, userOffset_),
            0
        );

        // Decoded data
        uint256 duration = BytesLib.toUint256(
            BytesLib.slice(
                _composeMsg,
                userOffset_,
                _composeMsg.length - userOffset_
            ),
            0
        );

        // Return structured data
        lockTwTapPositionMsg = LockTwTapPositionMsg(user, duration);
    }
}
