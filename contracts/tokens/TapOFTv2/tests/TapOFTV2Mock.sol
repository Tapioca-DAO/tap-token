// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// Tapioca
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

contract TapOFTV2Mock is TapOFTV2 {
    constructor(
        address _endpoint,
        address _twTap,
        address _owner
    ) TapOFTV2(_endpoint, _twTap, _owner) {}

    /**
     * @dev Internal function to build the message and options.
     *
     * @param _msg The TAP message to be encoded, for example `TapOFTSender.buildLockTwTapPositionMsg()`.
     * @param _msgType The message type, TAP custom ones, with `PT_` as a prefix.
     * @param _msgIndex The index of the current TAP compose msg.
     * @param _dstEid The destination endpoint ID.
     * @param _extraOptions Extra options for this message. Used to add extra options or aggregate previous `_tapComposeMsg` options.
     * @param _tapComposeMsg The previous TAP compose messages. Empty if this is the first message.
     *
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function buildTapComposeMsgAndOptions(
        bytes calldata _msg,
        uint16 _msgType,
        uint16 _msgIndex,
        uint32 _dstEid,
        bytes calldata _extraOptions,
        bytes calldata _tapComposeMsg
    ) external view returns (bytes memory message, bytes memory options) {
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

    /**
     * @dev Internal function to build the message and options.
     *
     * @param _sendParam The parameters for the send() operation.
     * @param _extraOptions Additional options for the send() operation.
     * @param _composeMsg The composed message for the send() operation.
     * @param _amountToCreditLD The amount to credit in local decimals.
     *
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function buildOFTMsgAndOptions(
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        bytes calldata _composeMsg,
        uint256 _amountToCreditLD
    ) external view returns (bytes memory message, bytes memory options) {
        return
            _buildOFTMsgAndOptions(
                _sendParam,
                _extraOptions,
                _composeMsg,
                _amountToCreditLD
            );
    }
}
