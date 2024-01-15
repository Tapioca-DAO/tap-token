// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    MessagingReceipt, OFTReceipt, SendParam
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {IOAppComposer} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppComposer.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    LockTwTapPositionMsg,
    ERC20PermitApprovalMsg,
    UnlockTwTapPositionMsg,
    LZSendParam,
    ClaimTwTapRewardsMsg,
    RemoteTransferMsg
} from "./ITapOFTv2.sol";
import {TapOFTMsgCoder} from "./TapOFTMsgCoder.sol";
import {BaseTapOFTv2} from "./BaseTapOFTv2.sol";
import {TapOFTSender} from "./TapOFTSender.sol";

// TODO remove console
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

contract TapOFTReceiver is BaseTapOFTv2, IOAppComposer {
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    constructor(address _endpoint, address _owner) BaseTapOFTv2(_endpoint, _owner) {}

    /**
     *  @dev Triggered if the address of the composer doesn't match current contract in `lzCompose`.
     * Compose caller and receiver are the same address, which is this.
     */
    error InvalidComposer(address composer);
    error InvalidCaller(address caller); // Should be the endpoint address
    // See `this._claimTwpTapRewardsReceiver()`. Triggered if the length of the claimed rewards are not equal to the length of the lzSendParam array.
    error InvalidSendParamLength(uint256 expectedLength, uint256 actualLength);

    /// @dev Compose received.
    event ComposeReceived(uint16 indexed msgType, bytes32 indexed guid, bytes composeMsg);

    /// @dev twTAP lock operation received.
    event LockTwTapReceived(address indexed user, uint96 duration, uint256 amount);
    /// @dev twTAP unlock operation received.
    event UnlockTwTapReceived(address indexed user, uint256 tokenId, uint256 amount);
    event RemoteTransferReceived(address indexed owner, uint256 indexed dstEid, address indexed to, uint256 amount);
    event ClaimRewardReceived(address indexed token, address indexed to, uint256 amount);

    /**
     * @dev !!! FIRST ENTRYPOINT, COMPOSE MSG ARE TO BE BUILT HERE  !!!
     *
     * @dev Slightly modified version of the OFT _lzReceive() operation.
     * The composed message is sent to `address(this)` instead of `toAddress`.
     * @dev Internal function to handle the receive on the LayerZero endpoint.
     * @dev Caller is verified on the public function. See `OAppReceiver.lzReceive()`.
     *
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded message.
     * _executor The address of the executor.
     * _extraData Additional data.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override {
        // @dev The src sending chain doesn't know the address length on this chain (potentially non-evm)
        // Thus everything is bytes32() encoded in flight.
        address toAddress = _message.sendTo().bytes32ToAddress();
        // @dev Convert the amount to credit into local decimals.
        uint256 amountToCreditLD = _toLD(_message.amountSD());
        // @dev Credit the amount to the recipient and return the ACTUAL amount the recipient received in local decimals
        uint256 amountReceivedLD = _credit(toAddress, amountToCreditLD, _origin.srcEid);

        if (_message.isComposed()) {
            // @dev Stores the lzCompose payload that will be executed in a separate tx.
            // Standardizes functionality for executing arbitrary contract invocation on some non-evm chains.
            // @dev The off-chain executor will listen and process the msg based on the src-chain-callers compose options passed.
            // @dev The index is used when a OApp needs to compose multiple msgs on lzReceive.
            // For default OFT implementation there is only 1 compose msg per lzReceive, thus its always 0.
            endpoint.sendCompose(
                address(this), // Updated from default `toAddress`
                _guid,
                0, /* the index of the composed message*/
                _message.composeMsg()
            );
        }

        emit OFTReceived(_guid, toAddress, amountToCreditLD, amountReceivedLD);
    }

    // TODO - SANITIZE MSG TYPE
    /**
     * @dev !!! SECOND ENTRYPOINT, CALLER NEEDS TO BE VERIFIED !!!
     *
     * @notice Composes a LayerZero message from an OApp.
     * @dev The message comes in form:
     *      - [composeSender::address][oftComposeMsg::bytes]
     *                                          |
     *                                          |
     *                        [msgType::uint16, composeMsg::bytes]
     * @dev The composeSender is the user that initiated the `sendPacket()` call on the srcChain.
     *
     * @param _from The address initiating the composition, typically the OApp where the lzReceive was called.
     * @param _guid The unique identifier for the corresponding LayerZero src/dst tx.
     * @param _message The composed message payload in bytes. NOT necessarily the same payload passed via lzReceive.
     */
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address, // _executor The address of the executor for the composed message.
        bytes calldata // _extraData Additional arbitrary data in bytes passed by the entity who executes the lzCompose.
    ) external payable override {
        // Validate the from and the caller.
        if (_from != address(this)) {
            revert InvalidComposer(_from);
        }
        if (msg.sender != address(endpoint)) {
            revert InvalidCaller(msg.sender);
        }

        // Decode LZ compose message.
        (address srcChainSender_, bytes memory oftComposeMsg_) = TapOFTMsgCoder.decodeLzComposeMsg(_message);

        // Decode OFT compose message.
        (uint16 msgType_,, uint16 msgIndex_, bytes memory tapComposeMsg_, bytes memory nextMsg_) =
            TapOFTMsgCoder.decodeTapComposeMsg(oftComposeMsg_);

        if (msgType_ == PT_APPROVALS) {
            _erc20PermitApprovalReceiver(tapComposeMsg_);
        } else if (msgType_ == PT_NFT_APPROVALS) {
            _erc721PermitApprovalReceiver(tapComposeMsg_);
        } else if (msgType_ == PT_LOCK_TWTAP) {
            _lockTwTapPositionReceiver(srcChainSender_, tapComposeMsg_);
        } else if (msgType_ == PT_UNLOCK_TWTAP) {
            _unlockTwTapPositionReceiver(tapComposeMsg_);
        } else if (msgType_ == PT_CLAIM_REWARDS) {
            _claimTwpTapRewardsReceiver(tapComposeMsg_);
        } else if (msgType_ == PT_REMOTE_TRANSFER) {
            _remoteTransferReceiver(srcChainSender_, tapComposeMsg_);
        } else {
            revert InvalidMsgType(msgType_);
        }

        emit ComposeReceived(msgType_, _guid, _message);

        if (nextMsg_.length > 0) {
            endpoint.sendCompose(
                address(this),
                _guid,
                msgIndex_ + 1, // Increment the index
                abi.encodePacked(OFTMsgCodec.addressToBytes32(srcChainSender_), nextMsg_) // Re encode the compose msg with the composeSender
            );
        }
    }

    // ********************* //
    // ***** RECEIVERS ***** //
    // ********************* //

    /**
     * @dev Locks TAP for the user in the twTAP contract.
     * @dev The user needs to have approved the TapOFTv2 contract to spend the TAP.
     *
     * @param _srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the lock.
     *          - user::address: Address of the user to lock the TAP for.
     *          - duration::uint96: Amount of time to lock for.
     *          - amount::uint256: Amount of TAP to lock.
     */

    // TODO sanitize the user to use approve on behalf of him
    function _lockTwTapPositionReceiver(address _srcChainSender, bytes memory _data) internal virtual {
        LockTwTapPositionMsg memory lockTwTapPositionMsg_ = TapOFTMsgCoder.decodeLockTwpTapDstMsg(_data);

        /// @dev xChain owner needs to have approved dst srcChain `sendPacket()` msg.sender in a previous composedMsg. Or be the same address.
        _internalTransferWithAllowance(lockTwTapPositionMsg_.user, _srcChainSender, lockTwTapPositionMsg_.amount);

        _approve(address(this), address(twTap), lockTwTapPositionMsg_.amount);
        twTap.participate(lockTwTapPositionMsg_.user, lockTwTapPositionMsg_.amount, lockTwTapPositionMsg_.duration);

        emit LockTwTapReceived(lockTwTapPositionMsg_.user, lockTwTapPositionMsg_.duration, lockTwTapPositionMsg_.amount);
    }

    /**
     * @dev Unlocks TAP for the user in the twTAP contract.
     * @dev !!! The user needs to have given TwTAP allowance to this contract in order to exit  !!!
     *
     * @param _data The call data containing info about the lock.
     *          - unlockTwTapPositionMsg_::UnlockTwTapPositionMsg: Unlocking data.
     */
    function _unlockTwTapPositionReceiver(bytes memory _data) internal virtual {
        UnlockTwTapPositionMsg memory unlockTwTapPositionMsg_ = TapOFTMsgCoder.decodeUnlockTwTapPositionMsg(_data);

        // Send TAP to the user address.
        uint256 tapAmount_ = twTap.exitPosition(unlockTwTapPositionMsg_.tokenId, unlockTwTapPositionMsg_.user);

        emit UnlockTwTapReceived(unlockTwTapPositionMsg_.user, unlockTwTapPositionMsg_.tokenId, tapAmount_);
    }

    /**
     * // TODO Check if it's safe to send composed messages too.
     * // TODO Write test for composed messages call. A->B->A-B/C?
     * @dev Transfers tokens AND composed messages from this contract to the recipient on the chain A. Flow of calls is: A->B->A.
     * @dev The user needs to have approved the TapOFTv2 contract to spend the TAP.
     *
     * @param _srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the transfer (LZSendParam).
     */
    function _remoteTransferReceiver(address _srcChainSender, bytes memory _data) internal virtual {
        RemoteTransferMsg memory remoteTransferMsg_ = TapOFTMsgCoder.decodeRemoteTransferMsg(_data);

        /// @dev xChain owner needs to have approved dst srcChain `sendPacket()` msg.sender in a previous composedMsg. Or be the same address.
        _internalTransferWithAllowance(
            remoteTransferMsg_.owner, _srcChainSender, remoteTransferMsg_.lzSendParam.sendParam.amountToSendLD
        );

        // Make the internal transfer, burn the tokens from this contract and send them to the recipient on the other chain.
        _internalRemoteTransferSendPacket(
            remoteTransferMsg_.owner, remoteTransferMsg_.lzSendParam, remoteTransferMsg_.composeMsg
        );

        emit RemoteTransferReceived(
            remoteTransferMsg_.owner,
            remoteTransferMsg_.lzSendParam.sendParam.dstEid,
            OFTMsgCodec.bytes32ToAddress(remoteTransferMsg_.lzSendParam.sendParam.to),
            remoteTransferMsg_.lzSendParam.sendParam.amountToSendLD
        );
    }

    /**
     * // TODO review this function.
     *
     * @dev Slightly modified version of the OFT _sendPacket() operation. To accommodate the `srcChainSender` parameter and potential dust.
     * @dev !!! IMPORTANT !!! made ONLY for the `_remoteTransferReceiver()` operation.
     */
    function _internalRemoteTransferSendPacket(
        address _srcChainSender,
        LZSendParam memory _lzSendParam,
        bytes memory _composeMsg
    ) internal returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        // Burn tokens from this contract
        (uint256 amountDebitedLD_, uint256 amountToCreditLD_) =
            _debitThis(_lzSendParam.sendParam.minAmountToCreditLD, _lzSendParam.sendParam.dstEid);

        _lzSendParam.sendParam.amountToSendLD = amountToCreditLD_;
        _lzSendParam.sendParam.minAmountToCreditLD = amountToCreditLD_;

        // If the srcChain amount request is bigger than the debited one, overwrite the amount to credit with the amount debited and send the difference back to the user.
        if (_lzSendParam.sendParam.amountToSendLD > amountDebitedLD_) {
            // Overwrite the amount to credit with the amount debited
            _lzSendParam.sendParam.amountToSendLD = amountDebitedLD_;
            _lzSendParam.sendParam.minAmountToCreditLD = amountDebitedLD_;
            // Send the difference back to the user
            _transfer(address(this), _srcChainSender, _lzSendParam.sendParam.amountToSendLD - amountDebitedLD_);
        }

        // Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildOFTMsgAndOptionsMemory(
            _lzSendParam.sendParam, _lzSendParam.extraOptions, _composeMsg, amountToCreditLD_, _srcChainSender
        ); // msgSender is the sender of the composed message. We keep context by passing `_srcChainSender`.

        // Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt =
            _lzSend(_lzSendParam.sendParam.dstEid, message, options, _lzSendParam.fee, _lzSendParam.refundAddress);
        // Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountDebitedLD_, amountToCreditLD_);

        emit OFTSent(msgReceipt.guid, _srcChainSender, amountDebitedLD_, amountToCreditLD_, _composeMsg);
    }

    /**
     * @dev Transfers tokens from this contract to the recipient on the chain A. Flow of calls is: A->B->A.
     * @dev !!! The user needs to have given TwTAP allowance to this contract  !!!
     *
     * @param _data The call data containing info about the transfer (LZSendParam).
     */
    function _claimTwpTapRewardsReceiver(bytes memory _data) internal virtual {
        ClaimTwTapRewardsMsg memory claimTwTapRewardsMsg_ = TapOFTMsgCoder.decodeClaimTwTapRewardsMsg(_data);

        // Claim rewards, make sure to have approved this contract on TwTap.
        uint256[] memory claimedAmount_ = twTap.claimRewards(claimTwTapRewardsMsg_.tokenId, address(this));

        // Check if the claimed amount is equal to the amount of sendParam
        if (
            (claimedAmount_.length - 1) // Remove 1 because the first index doesn't count.
                != claimTwTapRewardsMsg_.sendParam.length
        ) {
            revert InvalidSendParamLength(claimedAmount_.length, claimTwTapRewardsMsg_.sendParam.length);
        }

        // Loop over the tokens, and send them.
        IERC20[] memory rewardTokens_ = twTap.getRewardTokens();
        uint256 rewardTokensLength_ = rewardTokens_.length;

        /// @dev Reward token indexes starts at 1, 0 is reserved.
        /// The index of the claimedAmount_ array is the same as the reward token index.
        /// The index of claimTwTapRewardsMsg_.sendParam should be the same as the reward token index - 1, since it doesn't have the reserved 0 index.
        /// Take that into account when accessing the arrays.
        for (uint256 i = 1; i < rewardTokensLength_;) {
            uint256 sendParamIndex = i - 1; // Remove 1 to account for the reserved 0 index.
            address sendTo_ = OFTMsgCodec.bytes32ToAddress(claimTwTapRewardsMsg_.sendParam[sendParamIndex].sendParam.to);
            address rewardToken_ = address(rewardTokens_[i]);

            // Sanitize the amount to send
            uint256 amountWithoutDust = _removeDust(claimedAmount_[i]);
            uint256 dust = claimedAmount_[i] - amountWithoutDust;

            // Send the dust back to the user locally
            if (dust > 0) {
                // TODO Use SafeTransfer
                IERC20(rewardToken_).transfer(sendTo_, dust);
            }

            // Add 1 to `claimedAmount_` index because the first index is reserved.
            claimTwTapRewardsMsg_.sendParam[sendParamIndex].sendParam.amountToSendLD = amountWithoutDust; // Set the amount to send to the claimed amount
            claimTwTapRewardsMsg_.sendParam[sendParamIndex].sendParam.minAmountToCreditLD = amountWithoutDust; // Set the amount to send to the claimed amount

            // Send back packet
            TapOFTSender(rewardToken_).sendPacket{value: claimTwTapRewardsMsg_.sendParam[sendParamIndex].fee.nativeFee}(
                claimTwTapRewardsMsg_.sendParam[sendParamIndex], bytes("")
            );

            emit ClaimRewardReceived(rewardToken_, sendTo_, amountWithoutDust);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Performs a transfer with an allowance check and consumption against the xChain msg sender.
     * @dev Can only transfer to this address.
     *
     * @param _owner The account to transfer from.
     * @param srcChainSender The address of the sender on the source chain.
     * @param _amount The amount to transfer
     */
    function _internalTransferWithAllowance(address _owner, address srcChainSender, uint256 _amount) internal {
        if (_owner != srcChainSender) {
            _spendAllowance(_owner, srcChainSender, _amount);
        }

        _transfer(_owner, address(this), _amount);
    }

    /**
     * @notice Approves tokens via permit.
     * @param _data The call data containing info about the approvals.
     *      - token::address: Address of the token to approve.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - value::uint256: Amount of tokens to approve.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _erc20PermitApprovalReceiver(bytes memory _data) internal virtual {
        ERC20PermitApprovalMsg[] memory approvals = TapOFTMsgCoder.decodeArrayOfERC20PermitApprovalMsg(_data);

        tapOFTExtExec.erc20PermitApproval(approvals);
    }

    /**
     * @notice Approves NFT tokens via permit.
     * @param _data The call data containing info about the approvals.
     *      - token::address: Address of the token to approve.
     *      - spender::address: Address of the spender.
     *      - tokenId::uint256: TokenId of the token to approve.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _erc721PermitApprovalReceiver(bytes memory _data) internal virtual {
        ERC20PermitApprovalMsg[] memory approvals = TapOFTMsgCoder.decodeArrayOfERC20PermitApprovalMsg(_data);

        tapOFTExtExec.erc20PermitApproval(approvals);
    }

    /**
     * @dev For details about this function, check `BaseTapOFTv2._buildOFTMsgAndOptions()`.
     * @dev !!!! IMPORTANT !!!! The differences are:
     *      - memory instead of calldata for parameters.
     *      - `_msgSender` is used instead of using context `msg.sender`, to preserve context of the OFT call and use `msg.sender` of the source chain.
     *      - Does NOT combine options, make sure to pass valid options to cover gas costs/value transfers.
     */
    function _buildOFTMsgAndOptionsMemory(
        SendParam memory _sendParam,
        bytes memory _extraOptions,
        bytes memory _composeMsg,
        uint256 _amountToCreditLD,
        address _msgSender
    ) internal view returns (bytes memory message, bytes memory options) {
        bool hasCompose = _composeMsg.length > 0;

        message = hasCompose
            ? abi.encodePacked(
                _sendParam.to, _toSD(_amountToCreditLD), OFTMsgCodec.addressToBytes32(_msgSender), _composeMsg
            )
            : abi.encodePacked(_sendParam.to, _toSD(_amountToCreditLD));
        options = _extraOptions;

        if (msgInspector != address(0)) {
            IOAppMsgInspector(msgInspector).inspect(message, options);
        }
    }
}
