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
    ClaimTwTapRewardsMsg,
    RemoteTransferMsg
} from "@contracts/tokens/TapOFTv2/ITapOFTv2.sol";
import {
    TapOFTv2Helper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "@contracts/tokens/TapOFTv2/extensions/TapOFTv2Helper.sol";
import {TapOFTMsgCoder} from "@contracts/tokens/TapOFTv2/TapOFTMsgCoder.sol";
import {TwTAP, Participation} from "@contracts/governance/twTAP.sol";
import {TapOFTReceiver} from "@contracts/tokens/TapOFTv2/TapOFTReceiver.sol";
import {TapOFTSender} from "@contracts/tokens/TapOFTv2/TapOFTSender.sol";
import {TapOFTV2Mock} from "../Mocks/TapOFTV2Mock.sol";

// Tapioca
import {TapOFTV2Test} from "./TapOFTV2.t.sol";
import {ERC721Mock} from "../Mocks/ERC721Mock.sol";

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
            deadline: block.timestamp + 1 days
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
                    lockTwTapPositionMsgReturn_.prepareLzCallReturn.composeOptions // Only restriction is to have it contain the actual compose option for the index, whether there are other composed calls or not.
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
     * @dev Integration test with both ERC721Permit, unlockTwTapPosition, ERC20Permit and sendRemoteTransfer
     */
    function test_multi_compose_exit_and_transfer() public {
        vm.startPrank(userA);

        // Global vars
        uint256 amountToSendLD_ = 1 ether;
        uint256 tokenId_ = 1;
        uint256 lockDuration_ = 1 weeks;
        // Participate, get token and skip 1 week
        {
            deal(address(bTapOFT), userA, amountToSendLD_);
            bTapOFT.approve(address(twTap), amountToSendLD_);
            twTap.participate(userA, amountToSendLD_, lockDuration_);
            skip(lockDuration_);
        }

        // First packet vars
        SetupERC721ApprovalMsgData memory erc721ApprovalsData_ = SetupERC721ApprovalMsgData({
            token: ITapOFTv2(address(aTapOFT)),
            prepareLzCallData: PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(userA),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_NFT_APPROVALS,
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
            approvalOn: address(twTap),
            userPrivateKey: userAPKey,
            permitData: new ERC721PermitStruct[](1)
        });
        erc721ApprovalsData_.permitData[0] = ERC721PermitStruct({
            tokenId: tokenId_,
            spender: address(bTapOFT),
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        SetupERC721ApprovalMsgReturn memory erc721ApprovalsReturn_ = _setupERC721ApprovalMsg(erc721ApprovalsData_);

        // Second packet vars + lzSend params + options
        SetupUnlockTwTapPositionMsgReturn memory unlockTwTapPositionMsgReturn_ = _setupUnlockTwTapPositionMsg(
            SetupUnlockTwTapPositionMsgData({
                token: ITapOFTv2(address(aTapOFT)),
                prepareLzCallData: PrepareLzCallData({
                    dstEid: bEid,
                    recipient: OFTMsgCodec.addressToBytes32(userA),
                    amountToSendLD: 0,
                    minAmountToCreditLD: 0,
                    msgType: PT_UNLOCK_TWTAP,
                    composeMsgData: ComposeMsgData({
                        index: 1,
                        gas: 1_000_000,
                        value: 0,
                        data: new bytes(0), // Will be written in the _setupUnlockTwTapPositionMsg function.
                        prevData: erc721ApprovalsReturn_.prepareLzCallReturn.composeMsg,
                        prevOptionsData: erc721ApprovalsReturn_.prepareLzCallReturn.composeOptions
                    }),
                    lzReceiveGas: 1_000_000,
                    lzReceiveValue: 0
                }),
                user: userA,
                tokenId: tokenId_
            })
        );

        // Third packet vars
        SetupERC20ApprovalMsgData memory erc20ApprovalsData_ = SetupERC20ApprovalMsgData({
            token: ITapOFTv2(address(aTapOFT)),
            prepareLzCallData: PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(userA),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_APPROVALS,
                composeMsgData: ComposeMsgData({
                    index: 2,
                    gas: 1_000_000,
                    value: 0,
                    data: new bytes(0), // Will be written in the _setupERC20ApprovalMsg function.
                    prevData: unlockTwTapPositionMsgReturn_.prepareLzCallReturn.composeMsg,
                    prevOptionsData: unlockTwTapPositionMsgReturn_.prepareLzCallReturn.composeOptions
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
            spender: address(address(this)),
            value: amountToSendLD_,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        SetupERC20ApprovalMsgReturn memory erc20ApprovalsReturn_ = _setupERC20ApprovalMsg(erc20ApprovalsData_);

        // Fourth packet vars
        SetupRemoteTransferMsgReturn memory remoteTransferReturn_ = _setupRemoteTransferMsg(
            SetupRemoteTransferMsgData({
                token: ITapOFTv2(address(aTapOFT)),
                prepareLzCallData: PrepareLzCallData({
                    dstEid: bEid,
                    recipient: OFTMsgCodec.addressToBytes32(userA),
                    amountToSendLD: 0,
                    minAmountToCreditLD: 0,
                    msgType: PT_REMOTE_TRANSFER,
                    composeMsgData: ComposeMsgData({
                        index: 3,
                        gas: 1_000_000,
                        value: 0,
                        data: new bytes(0), // Will be written in the _setupRemoteTransferMsg function.
                        prevData: erc20ApprovalsReturn_.prepareLzCallReturn.composeMsg,
                        prevOptionsData: erc20ApprovalsReturn_.prepareLzCallReturn.composeOptions
                    }),
                    lzReceiveGas: 1_000_000,
                    lzReceiveValue: 0
                }),
                dstToken: ITapOFTv2(address(bTapOFT)),
                targetEid: aEid,
                owner: userA,
                amount: amountToSendLD_
            })
        );

        // Send packets
        (MessagingReceipt memory msgReceipt_, OFTReceipt memory oftReceipt_) = aTapOFT.sendPacket{
            value: remoteTransferReturn_.prepareLzCallReturn.lzSendParam.fee.nativeFee
        }(remoteTransferReturn_.prepareLzCallReturn.lzSendParam, remoteTransferReturn_.prepareLzCallReturn.composeMsg);

        {
            verifyPackets(uint32(bEid), address(bTapOFT));
            // Verify first message (approval)
            __callLzCompose(
                LzOFTComposedData(
                    PT_NFT_APPROVALS,
                    msgReceipt_.guid,
                    remoteTransferReturn_.prepareLzCallReturn.composeMsg, // All of the composed messages.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    erc721ApprovalsReturn_.prepareLzCallReturn.composeOptions // All of the options aggregated options.
                )
            );
        }

        bytes memory secondMsg_;
        {
            // Verify second msg (unlock twTap)
            {
                (,,,, secondMsg_) =
                    TapOFTMsgCoder.decodeTapComposeMsg(remoteTransferReturn_.prepareLzCallReturn.composeMsg);
            }

            vm.expectEmit(true, true, true, false);
            emit ITapOFTv2.UnlockTwTapReceived(
                unlockTwTapPositionMsgReturn_.unlockTwTapPositionMsg.user, uint96(lockDuration_), amountToSendLD_
            );

            __callLzCompose(
                LzOFTComposedData(
                    PT_UNLOCK_TWTAP,
                    msgReceipt_.guid,
                    secondMsg_, // All of the composed messages, except the previous ones.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    // Only restriction is to have it contain the actual compose option for the index, whether there are other composed calls or not.
                    unlockTwTapPositionMsgReturn_.prepareLzCallReturn.composeOptions
                )
            );
        }

        bytes memory thirdMsg_;
        {
            // Verify third msg (approval)
            {
                (,,,, thirdMsg_) = TapOFTMsgCoder.decodeTapComposeMsg(secondMsg_);
            }

            __callLzCompose(
                LzOFTComposedData(
                    PT_APPROVALS,
                    msgReceipt_.guid,
                    thirdMsg_, // All of the composed messages, except the previous ones.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    // Only restriction is to have it contain the actual compose option for the index, whether there are other composed calls or not.
                    erc20ApprovalsReturn_.prepareLzCallReturn.composeOptions
                )
            );
        }

        {
            // Verify third msg (approval)
            bytes memory forthMsg_;
            {
                (,,,, forthMsg_) = TapOFTMsgCoder.decodeTapComposeMsg(thirdMsg_);
            }

            __callLzCompose(
                LzOFTComposedData(
                    PT_REMOTE_TRANSFER,
                    msgReceipt_.guid,
                    forthMsg_, // All of the composed messages, except the previous ones.
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive).
                    address(bTapOFT), // Compose receiver (at lzCompose).
                    userA,
                    // Only restriction is to have it contain the actual compose option for the index, whether there are other composed calls or not.
                    remoteTransferReturn_.prepareLzCallReturn.composeOptions
                )
            );
        }

        {
            assertEq(aTapOFT.balanceOf(address(userA)), 0);
            verifyPackets(uint32(aEid), address(aTapOFT)); // Verify B->A transfer
            assertEq(aTapOFT.balanceOf(address(userA)), amountToSendLD_);
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
        ITapOFTv2 approvalOn;
        uint256 userPrivateKey;
        ERC20PermitStruct[] permitData;
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
                address(_data.approvalOn),
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
     * UNLOCK TWTAP  MSG BUILDER
     * ==========================
     */

    struct SetupUnlockTwTapPositionMsgData {
        PrepareLzCallData prepareLzCallData;
        ITapOFTv2 token;
        address user;
        uint256 tokenId;
    }

    struct SetupUnlockTwTapPositionMsgReturn {
        PrepareLzCallReturn prepareLzCallReturn;
        UnlockTwTapPositionMsg unlockTwTapPositionMsg;
    }

    function _setupUnlockTwTapPositionMsg(SetupUnlockTwTapPositionMsgData memory _data)
        internal
        returns (SetupUnlockTwTapPositionMsgReturn memory unlockTwTapPositionMsgReturn_)
    {
        UnlockTwTapPositionMsg memory unlockTwTapPositionMsg_ =
            UnlockTwTapPositionMsg({user: _data.user, tokenId: _data.tokenId});

        bytes memory unlockPosition_ = TapOFTMsgCoder.buildUnlockTwTapPositionMsg(unlockTwTapPositionMsg_);

        _data.prepareLzCallData.composeMsgData.data = unlockPosition_; // Overwrite data
        PrepareLzCallReturn memory prepareLzCallReturn_ =
            tapOFTv2Helper.prepareLzCall(_data.token, _data.prepareLzCallData);

        unlockTwTapPositionMsgReturn_ = SetupUnlockTwTapPositionMsgReturn({
            prepareLzCallReturn: prepareLzCallReturn_,
            unlockTwTapPositionMsg: unlockTwTapPositionMsg_
        });
    }

    /**
     * ==========================
     * UNLOCK TWTAP  MSG BUILDER
     * ==========================
     */
    /**
     * ==========================
     * REMOTE TRANSFER  MSG BUILDER
     * ==========================
     */

    struct SetupRemoteTransferMsgData {
        PrepareLzCallData prepareLzCallData;
        ITapOFTv2 token;
        ITapOFTv2 dstToken;
        uint32 targetEid;
        address owner;
        uint256 amount;
    }

    struct SetupRemoteTransferMsgReturn {
        PrepareLzCallReturn prepareLzCallReturn;
        RemoteTransferMsg remoteTransferMsg;
    }

    function _setupRemoteTransferMsg(SetupRemoteTransferMsgData memory _data)
        internal
        returns (SetupRemoteTransferMsgReturn memory RemoteTransferMsgReturn_)
    {
        // Prepare the remote call
        RemoteTransferMsg memory remoteTransferMsg_;
        {
            PrepareLzCallReturn memory prepareLzCallReturnRemoteTransfer_ = tapOFTv2Helper.prepareLzCall(
                _data.dstToken,
                PrepareLzCallData({
                    dstEid: _data.targetEid, // is the source, A : A->B->A
                    recipient: OFTMsgCodec.addressToBytes32(_data.owner),
                    amountToSendLD: _data.amount,
                    minAmountToCreditLD: _data.amount,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: new bytes(0),
                        prevData: new bytes(0),
                        prevOptionsData: new bytes(0)
                    }),
                    lzReceiveGas: 1_000_000,
                    lzReceiveValue: 0
                })
            );
            remoteTransferMsg_ = RemoteTransferMsg({
                owner: _data.owner,
                lzSendParam: prepareLzCallReturnRemoteTransfer_.lzSendParam,
                composeMsg: new bytes(0)
            });

            _data.prepareLzCallData.composeMsgData.value = uint128(prepareLzCallReturnRemoteTransfer_.msgFee.nativeFee); // Overwrite fees after computing it
        }

        bytes memory remoteTransfer_ = TapOFTMsgCoder.buildRemoteTransferMsg(remoteTransferMsg_);

        _data.prepareLzCallData.composeMsgData.data = remoteTransfer_; // Overwrite data
        PrepareLzCallReturn memory prepareLzCallReturn_ =
            tapOFTv2Helper.prepareLzCall(_data.token, _data.prepareLzCallData);

        RemoteTransferMsgReturn_ = SetupRemoteTransferMsgReturn({
            prepareLzCallReturn: prepareLzCallReturn_,
            remoteTransferMsg: remoteTransferMsg_
        });
    }

    /**
     * ==========================
     * REMOTE TRANSFER  MSG BUILDER
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
        address approvalOn;
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
                TwTAP(_data.approvalOn).getTypedDataHash(tapOftApprovals_),
                cacheData_.spender,
                _data.userPrivateKey
            );

            approvals_[i] = permitApproval_;

            unchecked {
                ++i;
            }
        }

        bytes memory approvalsMsg_ = tapOFTv2Helper.buildNftPermitApprovalMsg(approvals_);
        _data.prepareLzCallData.composeMsgData.data = approvalsMsg_; // Overwrite data

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
