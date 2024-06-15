// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// LZ
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    ITapToken,
    LockTwTapPositionMsg,
    UnlockTwTapPositionMsg,
    LZSendParam,
    ERC20PermitStruct,
    ERC721PermitStruct,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    ClaimTwTapRewardsMsg,
    RemoteTransferMsg
} from "tap-token/tokens/ITapToken.sol";
import {
    TapTokenHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "tap-token/tokens/extensions/TapTokenHelper.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {IPearlmit, Pearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {TapTokenReceiver} from "tap-token/tokens/TapTokenReceiver.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {TwTAP, Participation} from "tap-token/governance/twTAP.sol";
import {TapTokenSender} from "tap-token/tokens/TapTokenSender.sol";
import {TapTokenCodec} from "tap-token/tokens/TapTokenCodec.sol";
import {Cluster} from "tapioca-periph/Cluster/Cluster.sol";

// Tapioca Tests
import {TapTestHelper} from "./TapTestHelper.t.sol";
import {TapTokenMock} from "./TapTokenMock.sol";
import {ERC721Mock} from "./ERC721Mock.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

// TODO Split into multiple part?
contract TapTokenTest is TapTestHelper, IERC721Receiver {
    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    TapTokenMock aTapOFT;
    TapTokenMock bTapOFT;

    TapiocaOmnichainExtExec extExec;
    TapTokenHelper tapTokenHelper;

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public userA = vm.addr(userAPKey);
    address public userB = vm.addr(userBPKey);
    uint256 public initialBalance = 100 ether;
    uint256 EPOCH_DURATION = 1 weeks;

    /**
     * DEPLOY setup addresses
     */
    TwTAP twTap;
    address __endpoint;
    address __contributors = address(0x30);
    address __earlySupporters = address(0x31);
    address __supporters = address(0x32);
    address __lbp = address(0x33);
    address __dao = address(0x34);
    address __airdrop = address(0x35);
    uint256 __governanceEid = bEid;
    address __owner = address(this);
    Pearlmit pearlmit;
    Cluster cluster;

    /**
     * DEPLOY setup addresses
     */
    uint16 internal constant SEND = 1; // Send LZ message type
    uint16 internal constant PT_APPROVALS = 500;
    uint16 internal constant PT_NFT_APPROVALS = 501;
    uint16 internal constant PT_LOCK_TWTAP = 870;
    uint16 internal constant PT_UNLOCK_TWTAP = 871;
    uint16 internal constant PT_CLAIM_REWARDS = 872;
    uint16 internal constant PT_REMOTE_TRANSFER = 700;

    /**
     * @dev TapToken global event checks
     */
    event OFTReceived(bytes32, address, uint256, uint256);
    event ComposeReceived(uint16 indexed msgType, bytes32 indexed guid, bytes composeMsg);

    /**
     * @dev Setup the OApps by deploying them and setting up the endpoints.
     */
    function setUp() public override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.label(userA, "userA");
        vm.label(userB, "userB");

        setUpEndpoints(3, LibraryType.UltraLightNode);

        extExec = new TapiocaOmnichainExtExec();
        pearlmit = new Pearlmit("Pearlmit", "1", address(this), 0);
        cluster = new Cluster(aEid, __owner);

        aTapOFT = new TapTokenMock(
            ITapToken.TapTokenConstructorData(
                EPOCH_DURATION,
                address(endpoints[aEid]),
                __contributors,
                __earlySupporters,
                __supporters,
                __lbp,
                __dao,
                __airdrop,
                __governanceEid,
                address(this),
                address(new TapTokenSender("", "", address(endpoints[aEid]), address(this), address(0))),
                address(new TapTokenReceiver("", "", address(endpoints[aEid]), address(this), address(0))),
                address(extExec),
                IPearlmit(address(pearlmit)),
                ICluster(address(cluster))
            )
        );
        vm.label(address(aTapOFT), "aTapOFT");

        bTapOFT = new TapTokenMock(
            ITapToken.TapTokenConstructorData(
                EPOCH_DURATION,
                address(endpoints[bEid]),
                __contributors,
                __earlySupporters,
                __supporters,
                __lbp,
                __dao,
                __airdrop,
                __governanceEid,
                address(this),
                address(new TapTokenSender("", "", address(endpoints[bEid]), address(this), address(0))),
                address(new TapTokenReceiver("", "", address(endpoints[bEid]), address(this), address(0))),
                address(extExec),
                IPearlmit(address(pearlmit)),
                ICluster(address(cluster))
            )
        );
        vm.label(address(bTapOFT), "bTapOFT");

        twTap = new TwTAP(payable(address(bTapOFT)), IPearlmit(address(pearlmit)), address(this));
        vm.label(address(twTap), "twTAP");

        bTapOFT.setTwTAP(address(twTap));

        tapTokenHelper = new TapTokenHelper();
        // config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(aTapOFT);
        ofts[1] = address(bTapOFT);
        this.wireOApps(ofts);
    }

    /**
     * Allocation:
     * ============
     * DSO: 53,313,405
     * DAO: 8m
     * Contributors: 15m
     * Early supporters: 3,686,595
     * Supporters: 12.5m
     * LBP: 5m
     * Airdrop: 2.5m
     * == 100M ==
     */
    function test_constructor() public {
        // A tests
        assertEq(aTapOFT.owner(), address(this));
        assertEq(aTapOFT.token(), address(aTapOFT));
        assertEq(aTapOFT.totalSupply(), 0);
        assertEq(aTapOFT.governanceEid(), bEid);
        assertEq(address(aTapOFT.endpoint()), address(endpoints[aEid]));
        assertEq(address(aTapOFT.twTap()), address(0));

        // B tests
        assertEq(bTapOFT.owner(), address(this));
        assertEq(bTapOFT.token(), address(bTapOFT));
        assertEq(bTapOFT.totalSupply(), 46_686_595 ether); // Everything minus DSO
        assertEq(bTapOFT.INITIAL_SUPPLY(), 46_686_595 ether);
        assertEq(bTapOFT.governanceEid(), bEid);
        assertEq(address(bTapOFT.endpoint()), address(endpoints[bEid]));
        assertEq(address(bTapOFT.twTap()), address(twTap));
    }

    /**
     * @dev Can only be set once, and on host chain.
     */
    function test_set_tw_tap() public {
        // Can't set because not host chain
        vm.expectRevert(ITapToken.OnlyHostChain.selector);
        aTapOFT.setTwTAP(address(twTap));

        // Already set in `this.setUp()`
        vm.expectRevert(ITapToken.TwTapAlreadySet.selector);
        bTapOFT.setTwTAP(address(twTap));
    }

    function test_erc20_permit() public {
        ERC20PermitStruct memory permit_ =
            ERC20PermitStruct({owner: userA, spender: userB, value: 1e18, nonce: 0, deadline: 1 days});

        bytes32 digest_ = aTapOFT.getTypedDataHash(permit_);
        ERC20PermitApprovalMsg memory permitApproval_ =
            __getERC20PermitData(permit_, digest_, address(aTapOFT), userAPKey);

        aTapOFT.permit(
            permit_.owner,
            permit_.spender,
            permit_.value,
            permit_.deadline,
            permitApproval_.v,
            permitApproval_.r,
            permitApproval_.s
        );
        assertEq(aTapOFT.allowance(userA, userB), 1e18);
        assertEq(aTapOFT.nonces(userA), 1);
    }

    function test_erc721_permit() public {
        ERC721Mock erc721Mock = new ERC721Mock("Mock", "Mock");
        vm.label(address(erc721Mock), "erc721Mock");
        erc721Mock.mint(address(userA), 1);

        ERC721PermitStruct memory permit_ = ERC721PermitStruct({spender: userB, tokenId: 1, nonce: 0, deadline: 1 days});

        bytes32 digest_ = erc721Mock.getTypedDataHash(permit_);
        ERC721PermitApprovalMsg memory permitApproval_ =
            __getERC721PermitData(permit_, digest_, address(erc721Mock), userAPKey);

        erc721Mock.permit(
            permit_.spender, permit_.tokenId, permit_.deadline, permitApproval_.v, permitApproval_.r, permitApproval_.s
        );
        assertEq(erc721Mock.getApproved(1), userB);
        assertEq(erc721Mock.nonces(permit_.tokenId), 1);
    }

    /**
     * ERC20 APPROVALS
     */
    function test_tapOFT_erc20_approvals() public {
        address userC_ = vm.addr(0x3);

        ERC20PermitApprovalMsg memory permitApprovalB_;
        ERC20PermitApprovalMsg memory permitApprovalC_;
        bytes memory approvalsMsg_;

        {
            ERC20PermitStruct memory approvalUserB_ =
                ERC20PermitStruct({owner: userA, spender: userB, value: 1e18, nonce: 0, deadline: 1 days});
            ERC20PermitStruct memory approvalUserC_ = ERC20PermitStruct({
                owner: userA,
                spender: userC_,
                value: 2e18,
                nonce: 1, // Nonce is 1 because we already called permit() on userB
                deadline: 2 days
            });

            permitApprovalB_ = __getERC20PermitData(
                approvalUserB_, bTapOFT.getTypedDataHash(approvalUserB_), address(bTapOFT), userAPKey
            );

            permitApprovalC_ = __getERC20PermitData(
                approvalUserC_, bTapOFT.getTypedDataHash(approvalUserC_), address(bTapOFT), userAPKey
            );

            ERC20PermitApprovalMsg[] memory approvals_ = new ERC20PermitApprovalMsg[](2);
            approvals_[0] = permitApprovalB_;
            approvals_[1] = permitApprovalC_;

            approvalsMsg_ = tapTokenHelper.encodeERC20PermitApprovalMsg(approvals_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tapTokenHelper.prepareLzCall(
            ITapToken(address(aTapOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
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
                lzReceiveValue: 0,
                refundAddress: address(this)
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,, bytes memory msgSent,) =
            aTapOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTapOFT));

        vm.expectEmit(true, true, true, false);
        emit IERC20.Approval(userA, userB, 1e18);

        vm.expectEmit(true, true, true, false);
        emit IERC20.Approval(userA, userC_, 1e18);

        __callLzCompose(
            LzOFTComposedData(
                PT_APPROVALS,
                msgReceipt_.guid,
                msgSent,
                bEid,
                address(bTapOFT), // Compose creator (at lzReceive)
                address(bTapOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(bTapOFT.allowance(userA, userB), 1e18);
        assertEq(bTapOFT.allowance(userA, userC_), 2e18);
        assertEq(bTapOFT.nonces(userA), 2);
    }

    /**
     * ERC721 APPROVALS
     */
    function test_tapOFT_erc721_approvals() public {
        address userC_ = vm.addr(0x3);
        // Mint tokenId
        {
            deal(address(bTapOFT), address(userA), 1e18);
            deal(address(bTapOFT), address(userB), 1e18);

            vm.startPrank(userA);
            bTapOFT.approve(address(pearlmit), 1e18);
            pearlmit.approve(20, address(bTapOFT), 0, address(twTap), uint200(1e18), uint48(block.timestamp + 1));
            twTap.participate(address(userA), 1e18, 1 weeks);

            vm.startPrank(userB);
            bTapOFT.approve(address(pearlmit), 1e18);
            pearlmit.approve(20, address(bTapOFT), 0, address(twTap), uint200(1e18), uint48(block.timestamp + 1));
            twTap.participate(address(userB), 1e18, 1 weeks);
            vm.stopPrank();
        }

        ERC721PermitApprovalMsg memory permitApprovalB_;
        ERC721PermitApprovalMsg memory permitApprovalC_;
        bytes memory approvalsMsg_;

        {
            ERC721PermitStruct memory approvalUserB_ =
                ERC721PermitStruct({spender: userB, tokenId: 1, nonce: 0, deadline: 1 days});
            ERC721PermitStruct memory approvalUserC_ =
                ERC721PermitStruct({spender: userC_, tokenId: 2, nonce: 0, deadline: 1 days});

            permitApprovalB_ =
                __getERC721PermitData(approvalUserB_, twTap.getTypedDataHash(approvalUserB_), address(twTap), userAPKey);

            permitApprovalC_ =
                __getERC721PermitData(approvalUserC_, twTap.getTypedDataHash(approvalUserC_), address(twTap), userBPKey);

            ERC721PermitApprovalMsg[] memory approvals_ = new ERC721PermitApprovalMsg[](2);
            approvals_[0] = permitApprovalB_;
            approvals_[1] = permitApprovalC_;

            approvalsMsg_ = tapTokenHelper.encodeERC721PermitApprovalMsg(approvals_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tapTokenHelper.prepareLzCall(
            ITapToken(address(aTapOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_NFT_APPROVALS,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalsMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0,
                refundAddress: address(this)
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,, bytes memory msgSent,) =
            aTapOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTapOFT));

        vm.expectEmit(true, true, true, false);
        emit IERC721.Approval(userA, userB, 1);

        vm.expectEmit(true, true, true, false);
        emit IERC721.Approval(userB, userC_, 2);

        __callLzCompose(
            LzOFTComposedData(
                PT_NFT_APPROVALS,
                msgReceipt_.guid,
                msgSent,
                bEid,
                address(bTapOFT), // Compose creator (at lzReceive)
                address(bTapOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(twTap.getApproved(1), userB);
        assertEq(twTap.getApproved(2), userC_);
        assertEq(twTap.nonces(permitApprovalB_.tokenId), 1);
        assertEq(twTap.nonces(permitApprovalC_.tokenId), 1);
    }

    /**
     * @dev Test the OApp functionality of `TapToken.lockTwTapPosition()` function.
     */
    function test_lock_twTap_position() public {
        // TODO use userA in msg.sender context?
        // lock info
        uint256 amountToSendLD = 1 ether;
        uint96 lockDuration = 1 weeks;

        LockTwTapPositionMsg memory lockTwTapPositionMsg =
            LockTwTapPositionMsg({user: address(this), duration: lockDuration, amount: amountToSendLD});

        bytes memory lockPosition_ = TapTokenCodec.buildLockTwTapPositionMsg(lockTwTapPositionMsg);

        PrepareLzCallReturn memory prepareLzCallReturn_ = tapTokenHelper.prepareLzCall(
            ITapToken(address(aTapOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: amountToSendLD,
                minAmountToCreditLD: amountToSendLD,
                msgType: PT_LOCK_TWTAP,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: lockPosition_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0,
                refundAddress: address(this)
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        // Mint necessary tokens
        deal(address(aTapOFT), address(this), amountToSendLD);

        (MessagingReceipt memory msgReceipt_,, bytes memory msgSent,) =
            aTapOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTapOFT));

        vm.expectEmit(true, true, true, false);
        emit ITapToken.LockTwTapReceived(lockTwTapPositionMsg.user, lockTwTapPositionMsg.duration, amountToSendLD);

        __callLzCompose(
            LzOFTComposedData(
                PT_LOCK_TWTAP,
                msgReceipt_.guid,
                msgSent,
                bEid,
                address(bTapOFT), // Compose creator (at lzReceive)
                address(bTapOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        {
            Participation memory participation = twTap.getParticipation(1);
            assertEq(twTap.ownerOf(1), address(this));
            assertEq(participation.tapAmount, amountToSendLD);
            assertEq(participation.expiry, block.timestamp + lockDuration);
        }
    }

    /**
     * @dev Test the OApp functionality of `TapToken.unlockTwTapPosition()` function.
     */
    function test_unlock_twTap_position() public {
        /**
         * Prepare vars
         */

        // lock info
        uint256 lockAmount_ = 1 ether;
        uint96 lockDuration_ = 1 weeks;
        uint256 tokenId_; // tokenId of the TwTap position

        /**
         * Setup
         */
        {
            deal(address(bTapOFT), address(this), lockAmount_);
            bTapOFT.approve(address(pearlmit), lockAmount_);
            pearlmit.approve(20, address(bTapOFT), 0, address(twTap), uint200(lockAmount_), uint48(block.timestamp + 1));
            tokenId_ = twTap.participate(address(this), lockAmount_, lockDuration_);

            // Skip block timestamp to
            skip(lockDuration_);
        }

        /**
         * Actions
         */
        UnlockTwTapPositionMsg memory unlockTwTapPosition_ = UnlockTwTapPositionMsg({tokenId: tokenId_});
        bytes memory unlockTwTapPositionMsg_ = tapTokenHelper.buildUnlockTwpTapPositionMsg(unlockTwTapPosition_);

        PrepareLzCallReturn memory prepareLzCallReturn_ = tapTokenHelper.prepareLzCall(
            ITapToken(address(aTapOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_UNLOCK_TWTAP,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: unlockTwTapPositionMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0,
                refundAddress: address(this)
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,, bytes memory msgSent,) =
            aTapOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTapOFT));

        vm.expectEmit(true, true, true, false);
        emit ITapToken.UnlockTwTapReceived(unlockTwTapPosition_.tokenId, lockAmount_);

        __callLzCompose(
            LzOFTComposedData(
                PT_UNLOCK_TWTAP,
                msgReceipt_.guid,
                msgSent,
                bEid,
                address(bTapOFT), // Compose creator (at lzReceive)
                address(bTapOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );
    }

    /**
     * @dev Test the OApp functionality of `TapToken.unlockTwTapPosition()` function.
     */
    function test_remote_transfer() public {
        // vars
        uint256 tokenAmount_ = 1 ether;
        LZSendParam memory remoteLzSendParam_;
        MessagingFee memory remoteMsgFee_; // Will be used as value for the composed msg

        /**
         * Setup
         */
        {
            deal(address(bTapOFT), address(this), tokenAmount_);

            // @dev `remoteMsgFee_` is to be airdropped on dst to pay for the `remoteTransfer` operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tapTokenHelper.prepareLzCall( // B->A data
                ITapToken(address(bTapOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: tokenAmount_,
                    minAmountToCreditLD: tokenAmount_,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0,
                    refundAddress: address(this)
                })
            );
            remoteLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            remoteMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        RemoteTransferMsg memory remoteTransferData =
            RemoteTransferMsg({composeMsg: new bytes(0), owner: address(this), lzSendParam: remoteLzSendParam_});
        bytes memory remoteTransferMsg_ = tapTokenHelper.buildRemoteTransferMsg(remoteTransferData);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tapTokenHelper.prepareLzCall(
            ITapToken(address(aTapOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_REMOTE_TRANSFER,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 500_000,
                    value: uint128(remoteMsgFee_.nativeFee), // TODO Should we care about verifying cast boundaries?
                    data: remoteTransferMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 500_000,
                lzReceiveValue: 0,
                refundAddress: address(this)
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,, bytes memory msgSent,) =
            aTapOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTapOFT));

            // Initiate approval
            bTapOFT.approve(address(bTapOFT), tokenAmount_); // Needs to be pre approved on B chain to be able to transfer

            __callLzCompose(
                LzOFTComposedData(
                    PT_REMOTE_TRANSFER,
                    msgReceipt_.guid,
                    msgSent,
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive)
                    address(bTapOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // Check arrival
        {
            assertEq(aTapOFT.balanceOf(address(this)), 0);
            verifyPackets(uint32(aEid), address(aTapOFT)); // Verify B->A transfer
            assertEq(aTapOFT.balanceOf(address(this)), tokenAmount_);
        }
    }

    // Stack to deep
    struct TestClaimRewardsData {
        TapTokenMock erc20Mock1;
        TapTokenMock erc20Mock1Dst;
        TapTokenMock erc20Mock2;
        TapTokenMock erc20Mock2Dst;
        uint256 tokenAmount1;
        uint256 tokenAmount2;
        uint256 tokenId;
        LZSendParam remoteLzSendParam1;
        LZSendParam remoteLzSendParam2;
        MessagingFee remoteMsgFee1;
        MessagingFee remoteMsgFee2;
        uint256 expectReceive1;
        uint256 expectReceive2;
    }

    /**
     * @dev Test the OApp functionality of `TapToken.unlockTwTapPosition()` function.
     */
    function test_claim_rewards() public {
        // Init vars
        TestClaimRewardsData memory testData_;
        testData_.erc20Mock1 = _createNewToftToken("ERCM1", address(endpoints[bEid]));
        testData_.erc20Mock1Dst = _createNewToftToken("ERCM1", address(endpoints[aEid]));

        testData_.erc20Mock2 = _createNewToftToken("ERCM2", address(endpoints[bEid]));
        testData_.erc20Mock2Dst = _createNewToftToken("ERCM2", address(endpoints[aEid]));

        testData_.tokenAmount1 = 1 ether;
        testData_.tokenAmount2 = 2 ether;

        /**
         * Token setup
         */
        {
            address[] memory ofts = new address[](2);

            // Wire OFT mock 1
            ofts[0] = address(testData_.erc20Mock1);
            ofts[1] = address(testData_.erc20Mock1Dst);
            this.wireOApps(ofts);

            // Wire OFT mock 2
            ofts[0] = address(testData_.erc20Mock2);
            ofts[1] = address(testData_.erc20Mock2Dst);
            this.wireOApps(ofts);
        }

        /**
         * TwTAP setup
         */
        {
            uint256 lockAmount_ = 1 ether;
            // Participate
            deal(address(bTapOFT), address(this), lockAmount_);

            // bTapOFT.approve(address(twTap), lockAmount_);
            pearlmit.approve(20, address(bTapOFT), 0, address(twTap), uint200(lockAmount_), uint48(block.timestamp + 1));
            bTapOFT.approve(address(pearlmit), lockAmount_); // Approve pearlmit to transfer
            testData_.tokenId = twTap.participate(address(this), lockAmount_, 1 weeks);
            bTapOFT.approve(address(pearlmit), 0); // reset approval

            // Distribute rewards
            deal(address(testData_.erc20Mock1), address(this), testData_.tokenAmount1);
            deal(address(testData_.erc20Mock2), address(this), testData_.tokenAmount2);

            twTap.addRewardToken(testData_.erc20Mock1);
            twTap.addRewardToken(testData_.erc20Mock2);

            testData_.erc20Mock1.approve(address(twTap), testData_.tokenAmount1);
            testData_.erc20Mock2.approve(address(twTap), testData_.tokenAmount2);

            // Skip block timestamp to
            skip(1 weeks);

            twTap.advanceWeek(1);
            twTap.distributeReward(1, testData_.tokenAmount1); // Token index starts a 1, 0 is reserved
            twTap.distributeReward(2, testData_.tokenAmount2);

            // Compute claimable and receivable amounts. Without dust
            uint256[] memory claimableAmounts_ = twTap.claimable(testData_.tokenId);
            testData_.expectReceive1 = bTapOFT.removeDust(claimableAmounts_[1]);
            testData_.expectReceive2 = bTapOFT.removeDust(claimableAmounts_[2]);
        }

        /**
         * LZ calls setup
         */
        LZSendParam[] memory claimTwTapRewardsParam_ = new LZSendParam[](2);

        {
            // @dev `remoteMsgFee_` is to be airdropped on dst to pay for the `remoteTransfer` operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tapTokenHelper.prepareLzCall( // B->A data
                ITapToken(address(testData_.erc20Mock1)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: testData_.tokenAmount1,
                    minAmountToCreditLD: testData_.tokenAmount1,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0,
                    refundAddress: address(this)
                })
            );
            testData_.remoteMsgFee1 = prepareLzCallReturn1_.msgFee;
            testData_.remoteLzSendParam1 = prepareLzCallReturn1_.lzSendParam;

            // @dev `remoteMsgFee_` is to be airdropped on dst to pay for the `remoteTransfer` operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn2_ = tapTokenHelper.prepareLzCall( // B->A data
                ITapToken(address(testData_.erc20Mock2)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: testData_.tokenAmount2,
                    minAmountToCreditLD: testData_.tokenAmount2,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0,
                    refundAddress: address(this)
                })
            );
            testData_.remoteMsgFee2 = prepareLzCallReturn2_.msgFee;
            testData_.remoteLzSendParam2 = prepareLzCallReturn2_.lzSendParam;

            claimTwTapRewardsParam_[0] = testData_.remoteLzSendParam1;
            claimTwTapRewardsParam_[1] = testData_.remoteLzSendParam2;
        }

        /**
         * Actions
         */
        bytes memory claimTwTapRewardsMsg_;
        {
            ClaimTwTapRewardsMsg memory claimTwTapRewards_ =
                ClaimTwTapRewardsMsg({tokenId: testData_.tokenId, sendParam: claimTwTapRewardsParam_});
            claimTwTapRewardsMsg_ = tapTokenHelper.buildClaimRewardsMsg(claimTwTapRewards_);
        }

        bytes memory composeMsg_;
        bytes memory oftMsgOptions_;
        MessagingFee memory msgFee_;
        LZSendParam memory lzSendParam_;
        {
            PrepareLzCallReturn memory prepareLzCallReturn_ = tapTokenHelper.prepareLzCall(
                ITapToken(address(aTapOFT)),
                PrepareLzCallData({
                    dstEid: bEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: 0,
                    minAmountToCreditLD: 0,
                    msgType: PT_CLAIM_REWARDS,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 1_000_000,
                        value: uint128(testData_.remoteMsgFee1.nativeFee + testData_.remoteMsgFee2.nativeFee), // TODO Should we care about verifying cast boundaries?
                        data: claimTwTapRewardsMsg_,
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0,
                    refundAddress: address(this)
                })
            );
            composeMsg_ = prepareLzCallReturn_.composeMsg;
            oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
            msgFee_ = prepareLzCallReturn_.msgFee;
            lzSendParam_ = prepareLzCallReturn_.lzSendParam;
        }

        (MessagingReceipt memory msgReceipt_,, bytes memory msgSent,) =
            aTapOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            // A->B
            // Verify first sent packets

            verifyPackets(uint32(bEid), address(bTapOFT));

            // Initiate approval

            twTap.approve(address(bTapOFT), testData_.tokenId);

            __callLzCompose(
                LzOFTComposedData(
                    PT_CLAIM_REWARDS,
                    msgReceipt_.guid,
                    msgSent,
                    bEid,
                    address(bTapOFT), // Compose creator (at lzReceive)
                    address(bTapOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // B->A
        // Verify second sent packets
        {
            assertEq(testData_.erc20Mock1Dst.balanceOf(address(this)), 0);
            assertEq(testData_.erc20Mock2Dst.balanceOf(address(this)), 0);

            verifyPackets(uint32(aEid), address(testData_.erc20Mock1Dst));
            verifyPackets(uint32(aEid), address(testData_.erc20Mock2Dst));

            // Check sent balance
            assertEq(
                testData_.erc20Mock1Dst.balanceOf(address(this)),
                testData_.expectReceive1,
                "testData_.expectReceive1 received should be equal to claimable amount"
            );
            assertEq(
                testData_.erc20Mock2Dst.balanceOf(address(this)),
                testData_.expectReceive2,
                "testData_.expectReceive2 received should be equal to claimable amount"
            );
            // Check credited dust. Accept a delta of 1
            assertApproxEqAbs(
                testData_.erc20Mock1.balanceOf(address(this)),
                testData_.tokenAmount1 - testData_.expectReceive1,
                1,
                "Dust1 should be credited to dust address"
            );
            assertApproxEqAbs(
                testData_.erc20Mock2.balanceOf(address(this)),
                testData_.tokenAmount2 - testData_.expectReceive2,
                1,
                "Dust2 should be credited to dust address"
            );
        }
    }

    /**
     * @dev Receiver for `TapToken::PT_LOCK_TW_TAP` function.
     */
    function onERC721Received(
        address, // operator
        address, //from
        uint256, // tokenId
        bytes calldata // data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * =================
     *      HELPERS
     * =================
     */

    /**
     * @dev Used to bypass stack too deep
     *
     * @param msgType The message type of the lz Compose.
     * @param guid The message GUID.
     * @param composeMsg The source raw OApp compose message. If compose msg is composed with other msgs,
     * the msg should contain only the compose msg at its index and forward. I.E composeMsg[currentIndex:]
     * @param dstEid The destination EID.
     * @param from The address initiating the composition, typically the OApp where the lzReceive was called.
     * @param to The address of the lzCompose receiver.
     * @param srcMsgSender The address of src EID OFT `msg.sender` call initiator .
     * @param extraOptions The options passed in the source OFT call. Only restriction is to have it contain the actual compose option for the index,
     * whether there are other composed calls or not.
     */
    struct LzOFTComposedData {
        uint16 msgType;
        bytes32 guid;
        bytes composeMsg;
        uint32 dstEid;
        address from;
        address to;
        address srcMsgSender;
        bytes extraOptions;
    }

    /**
     * @notice Call lzCompose on the destination OApp.
     *
     * @dev Be sure to verify the message by calling `TestHelper.verifyPackets()`.
     * @dev Will internally verify the emission of the `ComposeReceived` event with
     * the right msgType, GUID and lzReceive composer message.
     *
     * @param _lzOFTComposedData The data to pass to the lzCompose call.
     */
    function __callLzCompose(LzOFTComposedData memory _lzOFTComposedData) internal {
        vm.expectEmit(true, true, true, false);
        emit ComposeReceived(_lzOFTComposedData.msgType, _lzOFTComposedData.guid, _lzOFTComposedData.composeMsg);

        this.lzCompose(
            _lzOFTComposedData.dstEid,
            _lzOFTComposedData.from,
            _lzOFTComposedData.extraOptions,
            _lzOFTComposedData.guid,
            _lzOFTComposedData.to,
            _lzOFTComposedData.composeMsg
        );
    }

    function _createNewToftToken(string memory _tokenLabel, address _endpoint)
        internal
        returns (TapTokenMock newToken_)
    {
        newToken_ = new TapTokenMock(
            ITapToken.TapTokenConstructorData(
                EPOCH_DURATION,
                _endpoint,
                __contributors,
                __earlySupporters,
                __supporters,
                __lbp,
                __dao,
                __airdrop,
                __governanceEid,
                address(this),
                address(new TapTokenSender("", "", _endpoint, address(this), address(extExec))),
                address(new TapTokenReceiver("", "", _endpoint, address(this), address(extExec))),
                address(extExec),
                IPearlmit(address(pearlmit)),
                ICluster(address(cluster))
            )
        );
        vm.label(address(newToken_), _tokenLabel);
    }
}
