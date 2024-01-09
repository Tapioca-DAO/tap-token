// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// External
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// Tapioca

import {ITapOFTv2, LockTwTapPositionMsg, ERC20PermitApprovalMsg, UnlockTwTapPositionMsg} from "../ITapOFTv2.sol";
import {TapOFTMsgCoder} from "../TapOFTMsgCoder.sol";
import {TapOFTV2} from "../TapOFTV2.sol";

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
 * @title TapOFTv2Helper
 * @author TapiocaDAO
 * @notice Used as a helper contract to build calls to the TapOFTv2 contract and view functions.
 */
contract TapOFTv2Helper {
    uint16 public constant PT_APPROVALS = 500;
    uint16 public constant PT_LOCK_TWTAP = 870;
    uint16 public constant PT_UNLOCK_TWTAP = 871;
    uint16 public constant PT_CLAIM_REWARDS = 872;

    error InvalidMsgType(uint16 msgType); // Triggered if the msgType is invalid on an `_lzCompose`.
    error InvalidMsgIndex(uint16 msgIndex, uint16 expectedIndex); // The msgIndex does not follow the sequence of indexes in the `_tapComposeMsg`
    error InvalidExtraOptionsIndex(uint16 msgIndex, uint16 expectedIndex); // The option index does not follow the sequence of indexes in the `_tapComposeMsg`

    /// =======================
    /// Builder functions
    /// =======================

    /**
     * @notice Encodes the message for the lockTwTapPosition() operation.
     **/
    function buildLockTwTapPositionMsg(
        LockTwTapPositionMsg calldata _lockTwTapPositionMsg
    ) public pure returns (bytes memory) {
        return TapOFTMsgCoder.buildLockTwTapPositionMsg(_lockTwTapPositionMsg);
    }

    /**
     * @notice Encode the message for the ercPermitApproval() operation.
     * @param _erc20PermitApprovalMsg The ERC20 permit approval messages.
     */
    function buildPermitApprovalMsg(
        ERC20PermitApprovalMsg[] calldata _erc20PermitApprovalMsg
    ) public pure returns (bytes memory msg_) {
        uint256 approvalsLength = _erc20PermitApprovalMsg.length;
        for (uint256 i; i < approvalsLength; ) {
            msg_ = abi.encodePacked(
                msg_,
                TapOFTMsgCoder.buildERC20PermitApprovalMsg(
                    _erc20PermitApprovalMsg[i]
                )
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Encodes the message for the unlockTwTapPosition() operation.
     **/
    function buildUnlockTwpTapPositionMsg(
        UnlockTwTapPositionMsg calldata _unlockTwTapPositionMsg
    ) public pure returns (bytes memory) {
        return
            TapOFTMsgCoder.buildUnlockTwTapPositionMsg(_unlockTwTapPositionMsg);
    }

    /**
     * @notice Decode an encoded message for the unlockTwTapPosition() operation.
     *
     * @param _msg The encoded message. see `TapOFTMsgCoder.buildUnlockTwTapPositionMsg()`
     * @return unlockTwTapPositionMsg_ The needed data.
     */
    function decodeUnlockTwTapPositionMsg(
        bytes calldata _msg
    ) public pure returns (UnlockTwTapPositionMsg memory) {
        return TapOFTMsgCoder.decodeUnlockTwTapPositionMsg(_msg);
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
        TapOFTV2 _tapOFTv2,
        bytes calldata _msg,
        uint16 _msgType,
        uint16 _msgIndex,
        uint32 _dstEid,
        bytes calldata _extraOptions,
        bytes calldata _tapComposedMsg
    ) public view returns (bytes memory message, bytes memory options) {
        _sanitizeMsgType(_msgType);
        _sanitizeMsgIndex(_msgIndex, _tapComposedMsg);

        message = TapOFTMsgCoder.encodeTapComposeMsg(
            _msg,
            _msgType,
            _msgIndex,
            _tapComposedMsg
        );

        _sanitizeExtraOptionsIndex(_msgIndex, _extraOptions);

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
}
