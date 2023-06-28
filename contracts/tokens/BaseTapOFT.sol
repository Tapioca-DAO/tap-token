// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ILayerZeroEndpoint} from "tapioca-sdk/dist/contracts/interfaces/ILayerZeroEndpoint.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {LzLib} from "tapioca-sdk/dist/contracts/libraries/LzLib.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
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
    uint16 internal constant PT_UNLOCK_TWTAP = 871;

    event CallFailedStr(uint16 _srcChainId, bytes _payload, string _reason);
    event CallFailedBytes(uint16 _srcChainId, bytes _payload, bytes _reason);

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
        } else if (packetType == PT_UNLOCK_TWTAP) {
            _unlockTwTapPosition(_srcChainId, _payload);
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

    /// --------------------------
    /// ------- LOCK TWTAP -------
    /// --------------------------

    /// @notice Opens a twTAP by participating in twAML.
    /// @param to The address to add the twTAP position to.
    /// @param amount The amount to add.
    /// @param lzDstChainId The destination chain id.
    /// @param zroPaymentAddress The address to send the ZRO payment to.
    /// @param adapterParams The adapter params.
    function lockTwTapPosition(
        address to,
        uint256 amount, // Amount to add
        uint256 duration, // Duration of the position.
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes calldata adapterParams
    ) external payable {
        bytes memory lzPayload = abi.encode(
            PT_LOCK_TWTAP, // packet type
            msg.sender,
            to,
            amount,
            duration
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
        (, , address to, uint256 amount, uint duration) = abi.decode(
            _payload,
            (uint16, address, address, uint256, uint256)
        );

        _creditTo(_srcChainId, address(this), amount);
        approve(address(twTap), amount);

        // We participate and mint with TapOFT as a receiver
        try twTap.participate(to, amount, duration) {} catch Error(
            string memory _reason
        ) {
            // If the process fails, we send back the funds to the user
            // We send back the funds to the user
            emit CallFailedStr(_srcChainId, _payload, _reason);
            _transferFrom(address(this), to, amount);
        } catch (bytes memory _reason) {
            emit CallFailedBytes(_srcChainId, _payload, _reason);
            _transferFrom(address(this), to, amount);
        }
    }

    /// --------------------------
    /// ------- UNLOCK TWTAP -------
    /// --------------------------

    /// @notice Exit a twTAP by participating in twAML.
    /// @param to The address to add the twTAP position to.
    /// @param tokenID Token ID of the twTAP position.
    /// @param lzDstChainId The destination chain id.
    /// @param zroPaymentAddress The address to send the ZRO payment to.
    /// @param adapterParams The adapter params.
    /// @param twTapSendBackAdapterParams The adapter params to send back the TAP token.
    function unlockTwTapPosition(
        address to,
        uint256 tokenID,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes calldata adapterParams,
        LzCallParams calldata twTapSendBackAdapterParams
    ) external payable {
        bytes memory lzPayload = abi.encode(
            PT_UNLOCK_TWTAP, // packet type
            msg.sender,
            to,
            tokenID,
            twTapSendBackAdapterParams
        );

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

    function _unlockTwTapPosition(
        uint16 _srcChainId,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            ,
            address to,
            uint256 tokenID,
            LzCallParams memory twTapSendBackAdapterParams
        ) = abi.decode(
                _payload,
                (uint16, address, address, uint256, LzCallParams)
            );

        // Exit and receive tokens to this contract
        try twTap.exitPositionAndSendTap(tokenID) returns (uint256 _amount) {
            // Transfer them to the user
            this.sendFrom{value: address(this).balance}(
                address(this),
                _srcChainID,
                _to,
                _amount,
                _twTapSendBackAdapterParams
            );
        } catch Error(string memory _reason) {
            emit CallFailedStr(_srcChainId, _payload, _reason);
        } catch (bytes memory _reason) {
            emit CallFailedBytes(_srcChainId, _payload, _reason);
        }
    }

    function __unlockAndSend(
        uint16 _srcChainID,
        bytes32 _to,
        uint256 _amount,
        LzCallParams memory _twTapSendBackAdapterParams
    ) internal {}

    function setTwTap(address _twTap) external onlyOwner {
        twTap = TwTAP(_twTap);
    }

    receive() external payable virtual {}

    function _callApproval(ITapiocaOFT.IApproval[] memory approvals) private {
        for (uint256 i = 0; i < approvals.length; ) {
            try
                IERC20Permit(approvals[i].target).permit(
                    approvals[i].owner,
                    approvals[i].spender,
                    approvals[i].value,
                    approvals[i].deadline,
                    approvals[i].v,
                    approvals[i].r,
                    approvals[i].s
                )
            {} catch Error(string memory reason) {
                if (!approvals[i].allowFailure) {
                    revert(reason);
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
