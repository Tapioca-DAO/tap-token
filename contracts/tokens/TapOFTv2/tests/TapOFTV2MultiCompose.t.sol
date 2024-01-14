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
import {
    TapOFTv2Helper, PrepareLzCallData, PrepareLzCallReturn, ComposeMsgData
} from "../extensions/TapOFTv2Helper.sol";
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
        SetupERC20ApprovalMsgData memory erc20ApprovalsData_ = SetupERC20ApprovalMsgData({
            token: ITapOFTv2(address(aTapOFT)),
            prepareLzCallData: PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(userA),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_APPROVALS,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: new bytes(0), // Will be written in the _setupERC20ApprovalMsg function.
                    prevData: new bytes(0),
                    prevOptionsData: new bytes(0)
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            }),
            approvalOn: ITapOFTv2(address(bTapOFT)),
            userPrivateKey: userAPKey,
            permitData: new ERC20PermitStruct[](1)
        });
        erc20ApprovalsData_.permitData[0] = ERC20PermitStruct({
            owner: userA,
            spender: address(bTapOFT),
            value: amountToSendLD,
            nonce: 0,
            deadline: 1 days
        });

        SetupERC20ApprovalMsgReturn memory erc20ApprovalsReturn_ = _setupERC20ApprovalMsg(erc20ApprovalsData_);

        // Second packet vars + lzSend params + options
        SetupLockTwTapPositionMsgReturn memory lockTwTapPositionMsgReturn_ = _setupLockTwTapPositionMsg(
            SetupLockTwTapPositionMsgData({
                token: ITapOFTv2(address(aTapOFT)),
                prepareLzCallData: PrepareLzCallData({
                    dstEid: bEid,
                    recipient: OFTMsgCodec.addressToBytes32(userA),
                    amountToSendLD: amountToSendLD, // We want to send the TAP to be locked
                    minAmountToCreditLD: amountToSendLD,
                    msgType: PT_LOCK_TWTAP,
                    composeMsgData: ComposeMsgData({
                        index: 1,
                        gas: 1_000_000,
                        value: 0,
                        data: new bytes(0), // Will be written in the _setupLockTwTapPositionMsg function.
                        prevData: erc20ApprovalsReturn_.prepareLzCallReturn.composeMsg,
                        prevOptionsData: erc20ApprovalsReturn_.prepareLzCallReturn.composeOptions
                    }),
                    lzReceiveGas: 1_000_000,
                    lzReceiveValue: 0
                }),
                user: userA,
                amountToSend: amountToSendLD,
                lockDuration: lockDuration
            })
        );

        deal(address(aTapOFT), userA, amountToSendLD); // Mint free tokens

        // Send packets
        (MessagingReceipt memory msgReceipt_, OFTReceipt memory oftReceipt_) = aTapOFT.sendPacket{
            value: lockTwTapPositionMsgReturn_.prepareLzCallReturn.lzSendParam.fee.nativeFee
        }(
            lockTwTapPositionMsgReturn_.prepareLzCallReturn.lzSendParam,
            lockTwTapPositionMsgReturn_.prepareLzCallReturn.composeMsg
        );

        {
            verifyPackets(uint32(bEid), address(bTapOFT));
            // Verify first message (approval)
            __callLzCompose(
                LzOFTComposedData(
                    PT_APPROVALS,
                    msgReceipt_.guid,
                    lockTwTapPositionMsgReturn_.prepareLzCallReturn.composeMsg, // All of the composed messages.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    lockTwTapPositionMsgReturn_.prepareLzCallReturn.oftMsgOptions // All of the options aggregated options.
                )
            );
        }
        {
            // Verify second msg (lock tw tap)
            bytes memory secondMsg_;
            {
                (,,,, secondMsg_) =
                    TapOFTMsgCoder.decodeTapComposeMsg(lockTwTapPositionMsgReturn_.prepareLzCallReturn.composeMsg);
            }

            vm.expectEmit(true, true, true, false);
            emit ITapOFTv2.LockTwTapReceived(
                lockTwTapPositionMsgReturn_.lockTwTapPositionMsg.user,
                lockTwTapPositionMsgReturn_.lockTwTapPositionMsg.duration,
                amountToSendLD
            );

            __callLzCompose(
                LzOFTComposedData(
                    PT_LOCK_TWTAP,
                    msgReceipt_.guid,
                    secondMsg_, // All of the composed messages, except the previous ones.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    lockTwTapPositionMsgReturn_.prepareLzCallReturn.composeOptions // All of the options, except the previous ones.
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

    /**
     * ==========================
     * ERC20 APPROVAL MSG BUILDER
     * ==========================
     */
    struct SetupERC20ApprovalMsgData {
        PrepareLzCallData prepareLzCallData;
        ITapOFTv2 token;
        uint256 userPrivateKey;
        ERC20PermitStruct[] permitData;
        ITapOFTv2 approvalOn;
    }

    struct SetupERC20ApprovalMsgReturn {
        PrepareLzCallReturn prepareLzCallReturn;
        ERC20PermitApprovalMsg[] approvals;
    }

    function _setupERC20ApprovalMsg(SetupERC20ApprovalMsgData memory _data)
        internal
        returns (SetupERC20ApprovalMsgReturn memory erc20ApprovalsReturn_)
    {
        ERC20PermitApprovalMsg[] memory approvals_ = new ERC20PermitApprovalMsg[](_data.permitData.length);

        uint256 dataLength_ = _data.permitData.length;
        ERC20PermitStruct memory cacheData_;
        for (uint256 i = 0; i < dataLength_;) {
            cacheData_ = _data.permitData[i];
            ERC20PermitStruct memory oftPermitStruct_ = ERC20PermitStruct({
                owner: cacheData_.owner,
                spender: cacheData_.spender,
                value: cacheData_.value,
                nonce: cacheData_.nonce,
                deadline: cacheData_.deadline
            });

            ERC20PermitApprovalMsg memory permitApproval_ = __getERC20PermitData(
                oftPermitStruct_,
                _data.approvalOn.getTypedDataHash(oftPermitStruct_),
                cacheData_.spender,
                _data.userPrivateKey
            );

            approvals_[i] = permitApproval_;

            unchecked {
                ++i;
            }
        }

        bytes memory approvalsMsg_ = tapOFTv2Helper.buildPermitApprovalMsg(approvals_);
        _data.prepareLzCallData.composeMsgData.data = approvalsMsg_; // Overwrite data

        erc20ApprovalsReturn_ = SetupERC20ApprovalMsgReturn({
            prepareLzCallReturn: tapOFTv2Helper.prepareLzCall(_data.token, _data.prepareLzCallData),
            approvals: approvals_
        });
    }
    /**
     * ==========================
     * ERC20 APPROVAL MSG BUILDER
     * ==========================
     */

    /**
     * ==========================
     * LOCK TWTAP  MSG BUILDER
     * ==========================
     */

    struct SetupLockTwTapPositionMsgData {
        PrepareLzCallData prepareLzCallData;
        ITapOFTv2 token;
        uint256 amountToSend;
        address user;
        uint96 lockDuration;
    }

    struct SetupLockTwTapPositionMsgReturn {
        PrepareLzCallReturn prepareLzCallReturn;
        LockTwTapPositionMsg lockTwTapPositionMsg;
    }

    function _setupLockTwTapPositionMsg(SetupLockTwTapPositionMsgData memory _data)
        internal
        returns (SetupLockTwTapPositionMsgReturn memory lockTwTapPositionMsgReturn_)
    {
        LockTwTapPositionMsg memory lockTwTapPositionMsg_ =
            LockTwTapPositionMsg({user: _data.user, duration: _data.lockDuration, amount: _data.amountToSend});

        bytes memory lockPosition_ = TapOFTMsgCoder.buildLockTwTapPositionMsg(lockTwTapPositionMsg_);

        _data.prepareLzCallData.composeMsgData.data = lockPosition_; // Overwrite data
        PrepareLzCallReturn memory prepareLzCallReturn_ =
            tapOFTv2Helper.prepareLzCall(_data.token, _data.prepareLzCallData);

        lockTwTapPositionMsgReturn_ = SetupLockTwTapPositionMsgReturn({
            prepareLzCallReturn: prepareLzCallReturn_,
            lockTwTapPositionMsg: lockTwTapPositionMsg_
        });
    }

    /**
     * ==========================
     * LOCK TWTAP  MSG BUILDER
     * ==========================
     */

    /**
     * ==========================
     * ERC721 APPROVALS  MSG BUILDER
     * ==========================
     */

    struct SetupERC721ApprovalMsgData {
        PrepareLzCallData prepareLzCallData;
        ITapOFTv2 token;
        uint256 userPrivateKey;
        ERC721PermitStruct[] permitData;
    }

    struct SetupERC721ApprovalMsgReturn {
        PrepareLzCallReturn prepareLzCallReturn;
        ERC721PermitApprovalMsg[] approvals;
    }

    function _setupERC721ApprovalMsg(SetupERC721ApprovalMsgData memory _data)
        internal
        returns (SetupERC721ApprovalMsgReturn memory erc721ApprovalsReturn_)
    {
        ERC721PermitApprovalMsg memory permitApproval_;

        uint256 dataLength_ = _data.permitData.length;
        ERC721PermitApprovalMsg[] memory approvals_ = new ERC721PermitApprovalMsg[](dataLength_);
        ERC721PermitStruct memory cacheData_;
        for (uint256 i = 0; i < dataLength_;) {
            cacheData_ = _data.permitData[i];
            ERC721PermitStruct memory tapOftApprovals_ = ERC721PermitStruct({
                spender: cacheData_.spender,
                tokenId: cacheData_.tokenId,
                nonce: cacheData_.nonce,
                deadline: cacheData_.deadline
            });

            permitApproval_ = __getERC721PermitData(
                tapOftApprovals_,
                TwTAP(address(_data.token)).getTypedDataHash(tapOftApprovals_),
                cacheData_.spender,
                _data.userPrivateKey
            );

            approvals_[i] = permitApproval_;

            unchecked {
                ++i;
            }
        }

        bytes memory approvalsMsg_ = tapOFTv2Helper.buildNftPermitApprovalMsg(approvals_);

        PrepareLzCallReturn memory prepareLzCallReturn_ =
            tapOFTv2Helper.prepareLzCall(_data.token, _data.prepareLzCallData);

        erc721ApprovalsReturn_ =
            SetupERC721ApprovalMsgReturn({prepareLzCallReturn: prepareLzCallReturn_, approvals: approvals_});
    }

    /**
     * ==========================
     * ERC721 APPROVALS  MSG BUILDER
     * ==========================
     */
}
