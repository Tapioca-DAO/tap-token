// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
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
 * @title TapOFTv2Helper
 * @author TapiocaDAO
 * @notice Used as a helper contract to build calls to the TapOFTv2 contract and view functions.
 */
// TODO build a helper for the LZSendParam and message fee
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
    function buildPermitApprovalMsg(ERC20PermitApprovalMsg[] calldata _erc20PermitApprovalMsg)
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
    function buildNftPermitApprovalMsg(ERC721PermitApprovalMsg[] calldata _erc721PermitApprovalMsg)
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
    function buildUnlockTwpTapPositionMsg(UnlockTwTapPositionMsg calldata _unlockTwTapPositionMsg)
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
    function _sanitizeMsgIndex(uint16 _msgIndex, bytes calldata _tapComposeMsg) internal pure {
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
    function _sanitizeExtraOptionsIndex(uint16 _msgIndex, bytes calldata _extraOptions) internal view {
        uint16 msgLength_ = TapOFTMsgCoder.decodeLengthOfExtraOptions(_extraOptions);

        // If the msgIndex is 0 and there's only 1 extra option, then it's the first message.
        if (_msgIndex == 0) {
            /// 19 = OptionType (1) + Index (8) + Gas (16)
            if (msgLength_ == 19 && _extraOptions.length == 24) {
                // Case where `value` was not encoded.
                return;
            }
            /// 35 = OptionType (1) + Index (8) + Gas (16) + Value (16)
            if (msgLength_ == 35 && _extraOptions.length == 40) {
                // Case where `value` was encoded.
                return;
            }
        }

        // Else check for the sequence of indexes.
        bytes memory nextMsg_ = _extraOptions;
        uint16 lastIndex_;
        while (nextMsg_.length > 0) {
            lastIndex_ = TapOFTMsgCoder.decodeIndexOfExtraOptions(nextMsg_);
            nextMsg_ = TapOFTMsgCoder.decodeNextMsgOfExtraOptions(nextMsg_);
        }

        // If there's a composeMsg, then the msgIndex must be greater than 0, and an increment of the last msgIndex.
        uint16 expectedMsgIndex_ = lastIndex_ + 1;
        if (_extraOptions.length > 0) {
            if (_msgIndex == expectedMsgIndex_) {
                return;
            }
        }

        revert InvalidExtraOptionsIndex(_msgIndex, expectedMsgIndex_);
    }
}
