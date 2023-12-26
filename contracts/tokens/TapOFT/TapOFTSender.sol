// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {MessagingReceipt, OFTReceipt, SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "../../libs/BytesLib.sol";

// Tapioca
import {BaseTapOFTv2} from "./BaseTapOFTv2.sol";
import {LZSendParam, LockTwTapPositionMsg} from "./ITapOFTv2.sol";

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
    using BytesLib for bytes;
    using SafeERC20 for IERC20;

    /**
     * @notice Encodes the message for the lockTwTapPosition() operation.
     **/
    function buildLockTwTapPositionMsg(
        LockTwTapPositionMsg calldata _lockTwTapPositionMsg
    ) external pure returns (bytes memory) {
        return
            abi.encode(
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
     * @param duration The duration of the twTAP lock.
     *
     * @return msgReceipt The receipt for the send operation.
     * @return oftReceipt The OFT receipt information.
     **/
    function lockTwTapPosition(
        LZSendParam calldata _lzSendParam,
        bytes calldata duration
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
                duration
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

    /**
     * @dev Internal function to build the message and options.
     * @param _msgType The message type, either custom ones with `PT_` as a prefix, or default OFT ones.
     * @param _sendParam The parameters for the send() operation.
     * @param _extraOptions Additional options for the send() operation.
     * @param _composeMsg The composed message for the send() operation.
     * @param _amountToCreditLD The amount to credit in local decimals.
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function _buildMsgAndOptionsByType(
        uint16 _msgType,
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        bytes calldata _composeMsg,
        uint256 _amountToCreditLD
    ) internal view returns (bytes memory message, bytes memory options) {
        // @dev This generated message has the msg.sender encoded into the payload so the remote knows who the caller is.
        (message, ) = OFTMsgCodec.encode(
            _sendParam.to,
            _toSD(_amountToCreditLD),
            // @dev Must be include a non empty bytes if you want to compose, EVEN if you dont need it on the remote.
            // EVEN if you dont require an arbitrary payload to be sent... eg. '0x01'
            abi.encode(_msgType, _composeMsg) // @dev Prepend `_msgType` on the compose msg.
        );

        // @dev Combine the callers _extraOptions with the enforced options via the OAppOptionsType3.
        options = combineOptions(_sendParam.dstEid, _msgType, _extraOptions);

        // @dev Optionally inspect the message and options depending if the OApp owner has set a msg inspector.
        // @dev If it fails inspection, needs to revert in the implementation. ie. does not rely on return boolean
        if (msgInspector != address(0))
            IOAppMsgInspector(msgInspector).inspect(message, options);
    }
}
