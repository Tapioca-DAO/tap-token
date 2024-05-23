// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    MessagingReceipt, OFTReceipt, SendParam
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {OFTCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Tapioca
import {
    ERC721PermitApprovalMsg,
    UnlockTwTapPositionMsg,
    ERC20PermitApprovalMsg,
    LockTwTapPositionMsg,
    ClaimTwTapRewardsMsg,
    RemoteTransferMsg,
    LZSendParam
} from "./ITapToken.sol";
import {TapiocaOmnichainReceiver} from "tapioca-periph/tapiocaOmnichainEngine/TapiocaOmnichainReceiver.sol";
import {IPearlmit} from "tapioca-periph/interfaces/periph/IPearlmit.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {ITOFT} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {TapTokenSender} from "./TapTokenSender.sol";
import {TapTokenCodec} from "./TapTokenCodec.sol";
import {BaseTapToken} from "./BaseTapToken.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract TapTokenReceiver is BaseTapToken, TapiocaOmnichainReceiver, ReentrancyGuard {
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;
    using SafeERC20 for IERC20;

    /**
     * @dev Used as a module for `TapToken`. Only delegate calls with `TapToken` state are used.
     * Set the Pearlmit and Cluster to address(0) because they are not used in this contract.
     */
    constructor(string memory _name, string memory _symbol, address _endpoint, address _delegate, address _extExec)
        BaseTapToken(_name, _symbol, _endpoint, _delegate, _extExec, IPearlmit(address(0)), ICluster(address(0)))
    {}

    /// @dev twTAP lock operation received.
    event LockTwTapReceived(address indexed user, uint96 duration, uint256 amount);
    /// @dev twTAP unlock operation received.
    event UnlockTwTapReceived(uint256 tokenId, uint256 amount);
    event ClaimRewardReceived(address indexed token, address indexed to, uint256 amount);

    // See `this._claimTwpTapRewardsReceiver()`. Triggered if the length of the claimed rewards are not equal to the length of the lzSendParam array.
    error InvalidSendParamLength(uint256 expectedLength, uint256 actualLength);

    // ********************* //
    // ***** RECEIVERS ***** //
    // ********************* //

    /**
     * @inheritdoc TapiocaOmnichainReceiver
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata _extraData /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override(OFTCore, TapiocaOmnichainReceiver) {
        TapiocaOmnichainReceiver._lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /**
     * @inheritdoc TapiocaOmnichainReceiver
     */
    function _toeComposeReceiver(uint16 _msgType, address _srcChainSender, bytes memory _toeComposeMsg)
        internal
        override
        nonReentrant
        returns (bool success)
    {
        if (_msgType == MSG_LOCK_TWTAP) {
            _lockTwTapPositionReceiver(_srcChainSender, _toeComposeMsg);
        } else if (_msgType == MSG_UNLOCK_TWTAP) {
            _unlockTwTapPositionReceiver(_toeComposeMsg);
        } else if (_msgType == MSG_CLAIM_REWARDS) {
            _claimTwpTapRewardsReceiver(_toeComposeMsg);
        } else {
            return false;
        }

        return true;
    }

    /**
     * @dev Locks TAP for the user in the twTAP contract.
     * @dev The user needs to have approved the TapToken contract to spend the TAP.
     *
     * @param _srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the lock.
     *          - user::address: Address of the user to lock the TAP for.
     *          - duration::uint96: Amount of time to lock for.
     *          - amount::uint256: Amount of TAP to lock.
     */

    // TODO sanitize the user to use approve on behalf of him
    function _lockTwTapPositionReceiver(address _srcChainSender, bytes memory _data) internal virtual twTapExists {
        LockTwTapPositionMsg memory lockTwTapPositionMsg_ = TapTokenCodec.decodeLockTwpTapDstMsg(_data);

        /// @dev xChain owner needs to have approved dst srcChain `sendPacket()` msg.sender in a previous composedMsg. Or be the same address.
        _internalTransferWithAllowance(lockTwTapPositionMsg_.user, _srcChainSender, lockTwTapPositionMsg_.amount);

        // _approve(address(this), address(twTap), lockTwTapPositionMsg_.amount);
        _approve(address(this), address(pearlmit), lockTwTapPositionMsg_.amount);
        pearlmit.approve(
            address(this), 0, address(twTap), uint200(lockTwTapPositionMsg_.amount), uint48(block.timestamp + 1)
        );
        twTap.participate(lockTwTapPositionMsg_.user, lockTwTapPositionMsg_.amount, lockTwTapPositionMsg_.duration);
        _approve(address(this), address(pearlmit), 0);

        emit LockTwTapReceived(lockTwTapPositionMsg_.user, lockTwTapPositionMsg_.duration, lockTwTapPositionMsg_.amount);
    }

    /**
     * @dev Unlocks TAP for the user in the twTAP contract.
     * @dev !!! The user needs to have given TwTAP allowance to this contract in order to exit  !!!
     *
     * @param _data The call data containing info about the lock.
     *          - unlockTwTapPositionMsg_::UnlockTwTapPositionMsg: Unlocking data.
     */
    function _unlockTwTapPositionReceiver(bytes memory _data) internal virtual twTapExists {
        UnlockTwTapPositionMsg memory unlockTwTapPositionMsg_ = TapTokenCodec.decodeUnlockTwTapPositionMsg(_data);

        // Send TAP to the user address.
        uint256 tapAmount_ = twTap.exitPosition(unlockTwTapPositionMsg_.tokenId);

        emit UnlockTwTapReceived(unlockTwTapPositionMsg_.tokenId, tapAmount_);
    }

    /**
     * @dev Transfers tokens from this contract to the recipient on the chain A. Flow of calls is: A->B->A.
     * @dev !!! The user needs to have given TwTAP allowance to this contract  !!!
     *
     * @param _data The call data containing info about the transfer (LZSendParam).
     */
    function _claimTwpTapRewardsReceiver(bytes memory _data) internal virtual twTapExists {
        ClaimTwTapRewardsMsg memory claimTwTapRewardsMsg_ = TapTokenCodec.decodeClaimTwTapRewardsMsg(_data);

        // Claim rewards, make sure to have approved this contract on TwTap.
        uint256[] memory claimedAmount_ = twTap.claimRewards(claimTwTapRewardsMsg_.tokenId);
        address owner = twTap.ownerOf(claimTwTapRewardsMsg_.tokenId);
        // Clear the allowance, claimRewards only does an allowance check.
        pearlmit.clearAllowance(owner, address(twTap), claimTwTapRewardsMsg_.tokenId);

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
            uint256 tokenDecimalConversionRate = ITOFT(rewardToken_).decimalConversionRate();
            uint256 amountWithoutDust = (claimedAmount_[i] / tokenDecimalConversionRate) * tokenDecimalConversionRate;
            uint256 dust = claimedAmount_[i] - amountWithoutDust;

            // Send the dust back to the user locally
            if (dust > 0) {
                IERC20(rewardToken_).safeTransfer(sendTo_, dust);
            }

            // Add 1 to `claimedAmount_` index because the first index is reserved.
            claimTwTapRewardsMsg_.sendParam[sendParamIndex].sendParam.amountLD = amountWithoutDust; // Set the amount to send to the claimed amount
            claimTwTapRewardsMsg_.sendParam[sendParamIndex].sendParam.minAmountLD = amountWithoutDust; // Set the amount to send to the claimed amount

            // Send back packet
            TapTokenSender(rewardToken_).sendPacket{
                value: claimTwTapRewardsMsg_.sendParam[sendParamIndex].fee.nativeFee
            }(claimTwTapRewardsMsg_.sendParam[sendParamIndex], bytes(""));

            emit ClaimRewardReceived(rewardToken_, sendTo_, amountWithoutDust);
            unchecked {
                ++i;
            }
        }
    }
}
