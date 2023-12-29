// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {MessagingReceipt, OFTReceipt, SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// Tapioca
import {BaseTapOFTv2} from "./BaseTapOFTv2.sol";
import {LZSendParam, LockTwTapPositionMsg} from "./ITapOFTv2.sol";

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
    ) external pure returns (bytes memory) {
        return
            abi.encodePacked(
                _lockTwTapPositionMsg._user,
                _lockTwTapPositionMsg._duration
            );
    }

    /**
     * @notice Opens a twTAP by participating in twAML.
     *
     * @param _lzSendParam The parameters for the send operation.
     *      - _sendParam The parameters for the send operation.
     *      - _fee The calculated fee for the send() operation.
     *          - nativeFee: The native fee.
     *          - lzTokenFee: The lzToken fee.
     *      - _extraOptions Additional options for the send() operation.
     *      - refundAddress The address to refund the native fee to.
     * @param _lockTwTapPositionMsg The encoded user and duration, see `buildLockTwTapPositionMsg()`
     *
     * @return msgReceipt The receipt for the send operation.
     * @return oftReceipt The OFT receipt information.
     **/
    function lockTwTapPosition(
        LZSendParam calldata _lzSendParam,
        bytes calldata _lockTwTapPositionMsg
    )
        external
        payable
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        )
    {
        return
            sendPacket(
                PT_LOCK_TWTAP,
                _lzSendParam._sendParam,
                _lzSendParam._extraOptions,
                _lzSendParam._fee,
                _lzSendParam.refundAddress,
                _lockTwTapPositionMsg
            );
    }

    /**
     * @dev Slightly modified version of the OFT send() operation. Includes a `_msgType` parameter.
     * The `_buildMsgAndOptionsByType()` appends the packet type to the message.
     * @dev Executes the send operation.
     * @param _msgType The message type, either custom ones with `PT_` as a prefix, or default OFT ones.
     * @param _sendParam The parameters for the send operation.
     * @param _extraOptions Additional options for the send() operation.
     * @param _fee The calculated fee for the send() operation.
     *      - nativeFee: The native fee.
     *      - lzTokenFee: The lzToken fee.
     * @param _refundAddress The address to receive any excess funds.
     * @param _composeMsg The composed message for the send() operation.
     * @return msgReceipt The receipt for the send operation.
     * @return oftReceipt The OFT receipt information.
     *
     * @dev MessagingReceipt: LayerZero msg receipt
     *  - guid: The unique identifier for the sent message.
     *  - nonce: The nonce of the sent message.
     *  - fee: The LayerZero fee incurred for the message.
     */
    function sendPacket(
        uint16 _msgType,
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        MessagingFee calldata _fee,
        address _refundAddress,
        bytes calldata _composeMsg
    )
        public
        payable
        virtual
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        )
    {
        // @dev Applies the token transfers regarding this send() operation.
        // - amountDebitedLD is the amount in local decimals that was ACTUALLY debited from the sender.
        // - amountToCreditLD is the amount in local decimals that will be credited to the recipient on the remote OFT instance.
        (uint256 amountDebitedLD, uint256 amountToCreditLD) = _debit(
            _sendParam.amountToSendLD,
            _sendParam.minAmountToCreditLD,
            _sendParam.dstEid
        );

        // @dev Builds the options and OFT message to quote in the endpoint.
        (
            bytes memory message,
            bytes memory options
        ) = _buildMsgAndOptionsByType(
                _msgType,
                _sendParam,
                _extraOptions,
                _composeMsg,
                amountToCreditLD
            );
        // console.log("0");
        // console.logBytes(message);
        // @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt = _lzSend(
            _sendParam.dstEid,
            message,
            options,
            _fee,
            _refundAddress
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
        emit PTMsgTypeSent(_msgType);
    }
}
