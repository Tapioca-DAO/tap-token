// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {MessagingReceipt, OFTReceipt, SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// Tapioca
import {LZSendParam, LockTwTapPositionMsg, ERC20PermitApprovalMsg} from "./ITapOFTv2.sol";
import {TapOFTMsgCoder} from "./TapOFTMsgCoder.sol";
import {BaseTapOFTv2} from "./BaseTapOFTv2.sol";

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

abstract contract TapOFTSender is BaseTapOFTv2 {
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
     * @notice Build a TapOFTv2 composed message and options. The composed message is a combination of 1 or more TAP specific messages.
     * @dev Internal `_msgIndex` sanitization is done to avoid errors in the composed message and the options.
     *
     * @param _msg The TAP message to be encoded.
     * @param _msgType The message type, TAP custom ones, with `PT_` as a prefix.
     * @param _msgIndex The index of the current TAP compose msg.
     * @param _dstEid The destination endpoint ID.
     * @param _extraOptions Extra options for this message. Used to add extra options or aggregate previous `_tapComposeMsg` options.
     * @param _tapComposeMsg The previous TAP compose messages. Empty if this is the first message.
     *
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function buildTapComposedMsg(
        bytes calldata _msg,
        uint16 _msgType,
        uint16 _msgIndex,
        uint32 _dstEid,
        bytes calldata _extraOptions,
        bytes calldata _tapComposeMsg
    ) public view returns (bytes memory message, bytes memory options) {
        return
            _buildTapComposeMsgAndOptions(
                _msg,
                _msgType,
                _msgIndex,
                _dstEid,
                _extraOptions,
                _tapComposeMsg
            );
    }

    // TODO make it public or only internal? Making it public would require more sanitization/security checks
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
    function sendPacket(
        LZSendParam calldata _lzSendParam,
        bytes calldata _composeMsg
    )
        public
        payable
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        )
    {
        // @dev Applies the token transfers regarding this send() operation.
        // - amountDebitedLD is the amount in local decimals that was ACTUALLY debited from the sender.
        // - amountToCreditLD is the amount in local decimals that will be credited to the recipient on the remote OFT instance.
        (uint256 amountDebitedLD, uint256 amountToCreditLD) = _debit(
            _lzSendParam.sendParam.amountToSendLD,
            _lzSendParam.sendParam.minAmountToCreditLD,
            _lzSendParam.sendParam.dstEid
        );

        // @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildOFTMsgAndOptions(
            _lzSendParam.sendParam,
            _lzSendParam.extraOptions,
            _composeMsg,
            amountToCreditLD
        );

        // @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt = _lzSend(
            _lzSendParam.sendParam.dstEid,
            message,
            options,
            _lzSendParam.fee,
            _lzSendParam.refundAddress
        );
        // @dev Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountDebitedLD, amountToCreditLD);

        emit OFTSent(
            msgReceipt.guid,
            msg.sender,
            amountDebitedLD,
            amountToCreditLD,
            _composeMsg
        );
    }
}
