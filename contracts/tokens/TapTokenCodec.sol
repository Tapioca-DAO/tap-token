// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

// LZ
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {
    ITapToken,
    LockTwTapPositionMsg,
    UnlockTwTapPositionMsg,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    LZSendParam,
    ClaimTwTapRewardsMsg,
    RemoteTransferMsg
} from "./ITapToken.sol";

import {TapiocaOmnichainEngineCodec} from "tapioca-periph/tapiocaOmnichainEngine/TapiocaOmnichainEngineCodec.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

library TapTokenCodec {
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
     * @param _msg The encoded message. see `TapTokenCodec.buildLockTwTapPositionMsg()`
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
     * @param _msg The encoded message. see `TapTokenCodec.buildUnlockTwTapPositionMsg()`
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
}
