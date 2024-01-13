// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// LZ
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    ITapOFTv2,
    LockTwTapPositionMsg,
    UnlockTwTapPositionMsg,
    LZSendParam,
    ERC20PermitStruct,
    ERC721PermitStruct,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    ClaimTwTapRewardsMsg
} from "../ITapOFTv2.sol";
import {TapOFTv2Helper} from "../extensions/TapOFTv2Helper.sol";
import {TapOFTMsgCoder} from "../TapOFTMsgCoder.sol";
import {TwTAP, Participation} from "../../../governance/TwTAP.sol";
import {TapOFTReceiver} from "../TapOFTReceiver.sol";
import {TapOFTSender} from "../TapOFTSender.sol";
import {TapOFTV2Mock} from "./TapOFTV2Mock.sol";

// Tapioca
import {TapOFTV2Test} from "./TapOFTV2.t.sol";
import {ERC721Mock} from "./ERC721Mock.sol";

import "forge-std/Test.sol";

contract TapOFTV2MultiComposeTest is TapOFTV2Test {
    /**
     * @dev Integration test with both ERC20Permit and lockTwTapPosition
     * @dev `userA` should be the sender
     */
    function test_multi_compose_participate() public {
        vm.startPrank(userA);

        // Global vars
        uint256 amountToSendLD = 1 ether;
        uint96 lockDuration = 1 weeks;

        // First packet vars
        (bytes memory permitComposeMsg_, bytes memory permitOftMsgOptions_) = _setupERC20ApprovalMsg(
            SetupERC20ApprovalMsgData({
                lzCallSrcContract: aTapOFT,
                dstEid: bEid,
                token: bTapOFT,
                owner: userA,
                spender: address(bTapOFT),
                amountToSend: amountToSendLD,
                nonce: 0,
                deadline: 1 days
            })
        );

        // Second packet vars
        LockTwTapPositionMsg memory lockTwTapPositionMsg_;
        bytes memory lockTwTapComposeMsg_;
        bytes memory lockTwTapOftMsgOptions_;

        // SendPacket vars
        LZSendParam memory lockTwTapLzSendParam_;
        bytes memory lzSendPacketOptions_;

        (
            lockTwTapPositionMsg_,
            lockTwTapComposeMsg_,
            lockTwTapOftMsgOptions_,
            lzSendPacketOptions_,
            lockTwTapLzSendParam_
        ) = _setupLockTwTapPositionMsg(
            SetupLockTwTapPositionMsgData({
                lzCallSrcContract: aTapOFT,
                dstEid: bEid,
                recipient: userA,
                amountToSend: amountToSendLD,
                lockDuration: lockDuration,
                prevComposeMsg: permitComposeMsg_,
                prevOptionsData: permitOftMsgOptions_
            })
        );

        deal(address(aTapOFT), userA, amountToSendLD);

        // Send packets
        (MessagingReceipt memory msgReceipt_, OFTReceipt memory oftReceipt_) =
            aTapOFT.sendPacket{value: lockTwTapLzSendParam_.fee.nativeFee}(lockTwTapLzSendParam_, lockTwTapComposeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTapOFT));
            // Verify first message (approval)
            __callLzCompose(
                LzOFTComposedData(
                    PT_APPROVALS,
                    msgReceipt_.guid,
                    lockTwTapComposeMsg_, // All of the composed messages.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    lzSendPacketOptions_ // All of the options aggregated options.
                )
            );
        }
        {
            // Verify second msg (lock tw tap)
            bytes memory secondMsg_;
            {
                (,,,, secondMsg_) = TapOFTMsgCoder.decodeTapComposeMsg(lockTwTapComposeMsg_);
            }

            vm.expectEmit(true, true, true, false);
            emit ITapOFTv2.LockTwTapReceived(lockTwTapPositionMsg_.user, lockTwTapPositionMsg_.duration, amountToSendLD);

            __callLzCompose(
                LzOFTComposedData(
                    PT_LOCK_TWTAP,
                    msgReceipt_.guid,
                    secondMsg_, // All of the composed messages, except the previous ones.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    lockTwTapOftMsgOptions_ // All of the options, except the previous ones.
                )
            );
        }

        {
            Participation memory participation = twTap.getParticipation(1);
            assertEq(twTap.ownerOf(1), userA);
            assertEq(participation.tapAmount, amountToSendLD);
            assertEq(participation.expiry, block.timestamp + lockDuration);
        }
    }

    struct SetupERC20ApprovalMsgData {
        TapOFTV2Mock lzCallSrcContract;
        TapOFTV2Mock token;
        uint32 dstEid;
        address owner;
        address spender;
        uint256 amountToSend;
        uint256 nonce;
        uint256 deadline;
    }

    function _setupERC20ApprovalMsg(SetupERC20ApprovalMsgData memory _data)
        internal
        returns (bytes memory permitComposeMsg_, bytes memory permitOftMsgOptions_)
    {
        ERC20PermitStruct memory bTapOftApproval_ = ERC20PermitStruct({
            owner: _data.owner,
            spender: _data.spender,
            value: _data.amountToSend,
            nonce: _data.nonce,
            deadline: _data.deadline
        });

        ERC20PermitApprovalMsg memory permitApproval_ = __getERC20PermitData(
            bTapOftApproval_, _data.token.getTypedDataHash(bTapOftApproval_), _data.spender, userAPKey
        );

        ERC20PermitApprovalMsg[] memory approvals_ = new ERC20PermitApprovalMsg[](1);
        approvals_[0] = permitApproval_;

        bytes memory approvalsMsg_ = tapOFTv2Helper.buildPermitApprovalMsg(approvals_);

        (,, permitComposeMsg_, permitOftMsgOptions_,,) = _prepareLzCall(
            _data.lzCallSrcContract,
            PrepareLzCallData({
                dstEid: _data.dstEid,
                recipient: OFTMsgCodec.addressToBytes32(_data.owner),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_APPROVALS,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalsMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
    }

    struct SetupLockTwTapPositionMsgData {
        TapOFTV2Mock lzCallSrcContract;
        uint32 dstEid;
        address recipient;
        uint256 amountToSend;
        uint96 lockDuration;
        bytes prevComposeMsg;
        bytes prevOptionsData;
    }

    function _setupLockTwTapPositionMsg(SetupLockTwTapPositionMsgData memory _data)
        internal
        returns (
            LockTwTapPositionMsg memory lockTwTapPositionMsg_,
            bytes memory lockTwTapComposeMsg_,
            bytes memory lockTwTapOftMsgOptions_,
            bytes memory lzSendPacketOptions_,
            LZSendParam memory lzSendParam_
        )
    {
        lockTwTapPositionMsg_ =
            LockTwTapPositionMsg({user: _data.recipient, duration: _data.lockDuration, amount: _data.amountToSend});

        bytes memory lockPosition_ = TapOFTMsgCoder.buildLockTwTapPositionMsg(lockTwTapPositionMsg_);

        (, lockTwTapOftMsgOptions_, lockTwTapComposeMsg_, lzSendPacketOptions_,, lzSendParam_) = _prepareLzCall(
            _data.lzCallSrcContract,
            PrepareLzCallData({
                dstEid: _data.dstEid,
                recipient: OFTMsgCodec.addressToBytes32(_data.recipient),
                amountToSendLD: _data.amountToSend,
                minAmountToCreditLD: _data.amountToSend,
                msgType: PT_LOCK_TWTAP,
                composeMsgData: ComposeMsgData({
                    index: 1,
                    gas: 1_000_000,
                    value: 0,
                    data: lockPosition_,
                    prevData: _data.prevComposeMsg,
                    prevOptionsData: _data.prevOptionsData
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
    }
}
