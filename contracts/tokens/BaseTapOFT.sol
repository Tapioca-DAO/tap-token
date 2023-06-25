// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ILayerZeroEndpoint} from "tapioca-sdk/dist/contracts/interfaces/ILayerZeroEndpoint.sol";
import {LzLib} from "tapioca-sdk/dist/contracts/libraries/LzLib.sol";
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";
import {TwTAP} from "../governance/twTAP.sol";

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

abstract contract BaseTapOFT is OFTV2 {
    using ExcessivelySafeCall for address;
    using BytesLib for bytes;

    TwTAP public twTap;

    uint16 internal constant PT_LOCK_TWTAP = 870;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _sharedDec,
        address _lzEndpoint
    ) OFTV2(_name, _symbol, _sharedDec, _lzEndpoint) {}

    //---LZ---
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint256 packetType = _payload.toUint256(0);

        if (packetType == PT_LOCK_TWTAP) {
            _lockTwTapPosition(_srcChainId, _payload);
        } else {
            packetType = _payload.toUint8(0);
            if (packetType == PT_SEND) {
                _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else if (packetType == PT_SEND_AND_CALL) {
                _sendAndCallAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else {
                revert("TOFT_packet");
            }
        }
    }

    /// @notice Opens a twTAP by participating in twAML.
    /// @param to The address to add the twTAP position to.
    /// @param amount The amount to add or remove.
    /// @param lzDstChainId The destination chain id.
    /// @param zroPaymentAddress The address to send the payment to.
    /// @param adapterParams The adapter params.
    /// @param twTapSendBackAdapterParams The adapter params to send back the twTAP/TAP token, depending on the action.
    function lockTwTapPosition(
        address to,
        uint256 amount, // Amount to add or remove
        uint256 duration, // Duration of the position. 0 if remove action
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes calldata adapterParams,
        bytes calldata twTapSendBackAdapterParams
    ) external payable {
        bytes memory lzPayload = abi.encode(
            PT_LOCK_TWTAP, // packet type
            msg.sender,
            to,
            amount,
            twTapSendBackAdapterParams
        );

        require(duration > 0, "TapOFT: Small duration");
        bytes32 senderBytes = LzLib.addressToBytes32(msg.sender);
        _debitFrom(msg.sender, lzEndpoint.getChainId(), senderBytes, amount);

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(msg.sender),
            zroPaymentAddress,
            adapterParams,
            msg.value
        );

        emit SendToChain(
            lzDstChainId,
            msg.sender,
            LzLib.addressToBytes32(to),
            0
        );
    }

    function _lockTwTapPosition(
        uint16 _srcChainId,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            ,
            address to,
            uint256 amount,
            uint duration,
            bytes memory twTapSendBackAdapterParams
        ) = abi.decode(
                _payload,
                (uint16, address, address, uint256, uint256, bytes)
            );

        // We participate and mint with TapOFT as a receiver
        try twTap.participate(address(this), amount, duration) returns (
            uint256 tokenID
        ) {
            // We transfer the minted tokens to the user
            twTap.sendFrom(
                address(this),
                _srcChainId,
                abi.encode(LzLib.addressToBytes32(to)),
                tokenID,
                payable(to),
                address(0),
                twTapSendBackAdapterParams
            );
        } catch {
            // If the process fails, we send back the funds to the user
            // We send back the funds to the user
            _creditTo(_srcChainId, to, amount);
        }
    }

    function setTwTap(address _twTap) external onlyOwner {
        twTap = TwTAP(_twTap);
    }
}
