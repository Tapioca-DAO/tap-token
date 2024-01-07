// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

import "forge-std/Test.sol";

// LZ
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Lib
import {TestHelper} from "./mocks/TestHelper.sol";

// Tapioca
import {ITapOFTv2, LockTwTapPositionMsg, LZSendParam, ERC20PermitStruct, ERC20PermitApprovalMsg} from "../ITapOFTv2.sol";
import {TapOFTMsgCoder} from "../TapOFTMsgCoder.sol";
import {TwTAP} from "../../../governance/TwTAP.sol";
import {TapOFTV2Mock} from "./TapOFTV2Mock.sol";

contract TapOFTV2Test is TestHelper {
    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    TapOFTV2Mock aTapOFT;
    TapOFTV2Mock bTapOFT;

    uint256 internal userAPKey = 0x1;
    uint256 internal userABKey = 0x2;
    address public userA = vm.addr(userAPKey);
    address public userB = vm.addr(userABKey);
    uint256 public initialBalance = 100 ether;

    /**
     * DEPLOY setup addresses
     */
    TwTAP twTap;
    address _endpoint;
    address _contributors = address(0x30);
    address _earlySupporters = address(0x31);
    address _supporters = address(0x32);
    address _lbp = address(0x33);
    address _dao = address(0x34);
    address _airdrop = address(0x35);
    uint256 _governanceEid = bEid;
    address _owner = address(this);
    /**
     * DEPLOY setup addresses
     */

    uint16 internal constant PT_APPROVALS = 500;
    uint16 internal constant PT_LOCK_TWTAP = 870;
    uint16 internal constant PT_UNLOCK_TWTAP = 871;
    uint16 internal constant PT_CLAIM_REWARDS = 872;

    /**
     * @dev TapOFTv2 global event checks
     */
    event OFTReceived(bytes32, address, uint256, uint256);
    event ComposeReceived(
        uint16 indexed msgType,
        bytes32 indexed guid,
        bytes composeMsg
    );

    /**
     * @dev Setup the OApps by deploying them and setting up the endpoints.
     */
    function setUp() public override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        setUpEndpoints(3, LibraryType.UltraLightNode);

        aTapOFT = TapOFTV2Mock(
            _deployOApp(
                type(TapOFTV2Mock).creationCode,
                abi.encode(
                    address(endpoints[aEid]),
                    _contributors,
                    _earlySupporters,
                    _supporters,
                    _lbp,
                    _dao,
                    _airdrop,
                    _governanceEid,
                    address(this)
                )
            )
        );
        vm.label(address(aTapOFT), "aTapOFT");
        bTapOFT = TapOFTV2Mock(
            _deployOApp(
                type(TapOFTV2Mock).creationCode,
                abi.encode(
                    address(endpoints[bEid]),
                    _contributors,
                    _earlySupporters,
                    _supporters,
                    _lbp,
                    _dao,
                    _airdrop,
                    _governanceEid,
                    address(this)
                )
            )
        );
        vm.label(address(bTapOFT), "bTapOFT");

        twTap = new TwTAP(payable(address(bTapOFT)), address(this));
        vm.label(address(twTap), "twTAP");

        bTapOFT.setTwTAP(address(twTap));

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
        vm.expectRevert(ITapOFTv2.OnlyHostChain.selector);
        aTapOFT.setTwTAP(address(twTap));

        // Already set in `this.setUp()`
        vm.expectRevert(ITapOFTv2.TwTapAlreadySet.selector);
        bTapOFT.setTwTAP(address(twTap));
    }

    function test_erc20_permit() public {
        ERC20PermitStruct memory permit_ = ERC20PermitStruct({
            owner: userA,
            spender: userB,
            value: 1e18,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest_ = aTapOFT.getTypedDataHash(permit_);
        ERC20PermitApprovalMsg memory permitApproval_ = __getERC20PermitData(
            permit_,
            digest_,
            address(aTapOFT),
            userAPKey
        );

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

    function test_tapOFT_erc20_approvals() public {
        address userC_ = vm.addr(0x3);

        ERC20PermitApprovalMsg memory permitApprovalB_;
        ERC20PermitApprovalMsg memory permitApprovalC_;
        bytes memory approvalsMsg_;

        {
            ERC20PermitStruct memory approvalUserB_ = ERC20PermitStruct({
                owner: userA,
                spender: userB,
                value: 1e18,
                nonce: 0,
                deadline: 1 days
            });
            ERC20PermitStruct memory approvalUserC_ = ERC20PermitStruct({
                owner: userA,
                spender: userC_,
                value: 2e18,
                nonce: 1, // Nonce is 1 because we already called permit() on userB
                deadline: 2 days
            });

            permitApprovalB_ = __getERC20PermitData(
                approvalUserB_,
                bTapOFT.getTypedDataHash(approvalUserB_),
                address(bTapOFT),
                userAPKey
            );

            permitApprovalC_ = __getERC20PermitData(
                approvalUserC_,
                bTapOFT.getTypedDataHash(approvalUserC_),
                address(bTapOFT),
                userAPKey
            );

            ERC20PermitApprovalMsg[]
                memory approvals_ = new ERC20PermitApprovalMsg[](2);
            approvals_[0] = permitApprovalB_;
            approvals_[1] = permitApprovalC_;

            approvalsMsg_ = aTapOFT.buildPermitApprovalMsg(approvals_);
        }

        (
            SendParam memory sendParam_,
            ,
            bytes memory composeMsg_,
            bytes memory oftMsgOptions_,
            MessagingFee memory msgFee_,
            LZSendParam memory lzSendParam_
        ) = __prepareLzCall(
                PrepareLzCall({
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
                        prevData: bytes("")
                    }),
                    lzReceiveGas: 1_000_000,
                    lzReceiveValue: 0
                })
            );

        (
            MessagingReceipt memory msgReceipt_,
            OFTReceipt memory oftReceipt_
        ) = aTapOFT.sendPacket{value: msgFee_.nativeFee}(
                lzSendParam_,
                composeMsg_
            );

        verifyPackets(
            uint32(bEid),
            OFTMsgCodec.addressToBytes32(address(bTapOFT))
        );

        vm.expectEmit(true, true, true, false);
        emit IERC20.Approval(userA, userB, 1e18);

        vm.expectEmit(true, true, true, false);
        emit IERC20.Approval(userA, userC_, 1e18);

        __callLzCompose(
            LzOFTComposedData(
                PT_APPROVALS,
                msgReceipt_.guid,
                composeMsg_,
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
     * @dev Test the OApp functionality of `TapOFTv2.lockTwTapPosition()` function.
     */
    function test_lock_twTap_position() public {
        // TODO use userA in msg.sender context
        // lock info
        uint256 amountToSendLD = 1 ether;
        uint96 lockDuration = 80;

        LockTwTapPositionMsg
            memory lockTwTapPositionMsg = LockTwTapPositionMsg({
                user: address(this),
                duration: lockDuration,
                amount: amountToSendLD
            });

        bytes memory lockPosition_ = TapOFTMsgCoder.buildLockTwTapPositionMsg(
            lockTwTapPositionMsg
        );

        (
            SendParam memory sendParam_,
            bytes memory composeOptions_,
            bytes memory composeMsg_,
            bytes memory oftMsgOptions_,
            MessagingFee memory msgFee_,
            LZSendParam memory lzSendParam_
        ) = __prepareLzCall(
                PrepareLzCall({
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
                        prevData: bytes("")
                    }),
                    lzReceiveGas: 1_000_000,
                    lzReceiveValue: 0
                })
            );

        // Mint necessary tokens
        deal(address(aTapOFT), address(this), amountToSendLD);

        (
            MessagingReceipt memory msgReceipt_,
            OFTReceipt memory oftReceipt_
        ) = aTapOFT.sendPacket{value: msgFee_.nativeFee}(
                lzSendParam_,
                composeMsg_
            );

        verifyPackets(
            uint32(bEid),
            OFTMsgCodec.addressToBytes32(address(bTapOFT))
        );

        // Fake approval
        bTapOFT.approve(address(bTapOFT), amountToSendLD);
        console.log(
            "bTapOFT.allowance(address(this), address(bTapOFT))",
            bTapOFT.allowance(address(this), address(bTapOFT))
        );

        vm.expectEmit(true, true, true, false);
        emit ITapOFTv2.LockTwTapReceived(
            lockTwTapPositionMsg.user,
            lockTwTapPositionMsg.duration,
            amountToSendLD
        );

        __callLzCompose(
            LzOFTComposedData(
                PT_LOCK_TWTAP,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTapOFT), // Compose creator (at lzReceive)
                address(bTapOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );
    }

    /**
     * =================
     *      HELPERS
     * =================
     */

    struct ComposeMsgData {
        uint8 index;
        uint128 gas;
        uint128 value;
        bytes data;
        bytes prevData;
    }
    struct PrepareLzCall {
        uint32 dstEid;
        bytes32 recipient;
        uint256 amountToSendLD;
        uint256 minAmountToCreditLD;
        uint16 msgType;
        ComposeMsgData composeMsgData;
        uint128 lzReceiveGas;
        uint128 lzReceiveValue;
    }

    /**
     * @dev Helper to prepare an LZ call.
     */
    function __prepareLzCall(
        PrepareLzCall memory _prepareLzCall
    )
        internal
        view
        returns (
            SendParam memory sendParam_,
            bytes memory composeOptions_,
            bytes memory composeMsg_,
            bytes memory oftMsgOptions_,
            MessagingFee memory msgFee_,
            LZSendParam memory lzSendParam_
        )
    {
        // Prepare args call
        sendParam_ = SendParam({
            dstEid: _prepareLzCall.dstEid,
            to: _prepareLzCall.recipient,
            amountToSendLD: _prepareLzCall.amountToSendLD,
            minAmountToCreditLD: _prepareLzCall.minAmountToCreditLD
        });

        composeOptions_ = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(
                _prepareLzCall.composeMsgData.index,
                _prepareLzCall.composeMsgData.gas,
                _prepareLzCall.composeMsgData.value
            );
        (composeMsg_, ) = aTapOFT.buildTapComposedMsg(
            _prepareLzCall.composeMsgData.data,
            _prepareLzCall.msgType,
            _prepareLzCall.composeMsgData.index,
            sendParam_.dstEid,
            composeOptions_,
            _prepareLzCall.composeMsgData.prevData // Previous tapComposeMsg
        );

        oftMsgOptions_ = OptionsBuilder.addExecutorLzReceiveOption(
            composeOptions_,
            _prepareLzCall.lzReceiveGas,
            _prepareLzCall.lzReceiveValue
        );
        msgFee_ = aTapOFT.quoteSendPacket(
            sendParam_,
            oftMsgOptions_,
            false,
            composeMsg_,
            ""
        );

        lzSendParam_ = LZSendParam({
            sendParam: sendParam_,
            fee: msgFee_,
            extraOptions: oftMsgOptions_,
            refundAddress: address(this)
        });
    }

    /**
     * @dev Used to bypass stack too deep
     *
     * @param msgType The message type of the lz Compose.
     * @param guid The message GUID.
     * @param composeMsg The source raw OApp compose message.
     * @param dstEid The destination EID.
     * @param from The address initiating the composition, typically the OApp where the lzReceive was called.
     * @param to The address of the lzCompose receiver.
     * @param srcMsgSender The address of src EID OFT `msg.sender` call initiator .
     * @param extraOptions The options passed in the source OFT call.
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
    function __callLzCompose(
        LzOFTComposedData memory _lzOFTComposedData
    ) internal {
        vm.expectEmit(true, true, true, false);
        emit ComposeReceived(
            _lzOFTComposedData.msgType,
            _lzOFTComposedData.guid,
            _lzOFTComposedData.composeMsg
        );

        this.lzCompose(
            _lzOFTComposedData.dstEid,
            _lzOFTComposedData.from,
            _lzOFTComposedData.extraOptions,
            _lzOFTComposedData.guid,
            _lzOFTComposedData.to,
            abi.encodePacked(
                OFTMsgCodec.addressToBytes32(_lzOFTComposedData.srcMsgSender),
                _lzOFTComposedData.composeMsg
            )
        );
    }

    /**
     * @dev Helper to build an ERC20PermitApprovalMsg.
     * @param _permit The permit data.
     * @param _digest The typed data digest.
     * @param _token The token contract to receive the permit.
     * @param _pkSigner The private key signer.
     */
    function __getERC20PermitData(
        ERC20PermitStruct memory _permit,
        bytes32 _digest,
        address _token,
        uint256 _pkSigner
    ) internal view returns (ERC20PermitApprovalMsg memory permitApproval_) {
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(_pkSigner, _digest);

        permitApproval_ = ERC20PermitApprovalMsg({
            token: _token,
            owner: _permit.owner,
            spender: _permit.spender,
            value: _permit.value,
            deadline: _permit.deadline,
            v: v_,
            r: r_,
            s: s_
        });
    }
}
