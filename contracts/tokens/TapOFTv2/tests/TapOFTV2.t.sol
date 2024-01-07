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

// Lib
import {TestHelper} from "./mocks/TestHelper.sol";

// Tapioca
import {LZSendParam, LockTwTapPositionMsg, ITapOFTv2} from "../ITapOFTv2.sol";
import {TwTAP} from "../../../governance/TwTAP.sol";
import {TapOFTMsgCoder} from "../TapOFTMsgCoder.sol";
import {TapOFTV2Mock} from "./TapOFTV2Mock.sol";

contract TapOFTV2Test is TestHelper {
    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    TapOFTV2Mock aTapOFT;
    TapOFTV2Mock bTapOFT;

    address public userA = address(0x1);
    address public userB = address(0x2);
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

    function test_set_tw_tap() public {
        // Can't set because not host chain
        vm.expectRevert(ITapOFTv2.OnlyHostChain.selector);
        aTapOFT.setTwTAP(address(twTap));

        // Already set in `this.setUp()`
        vm.expectRevert(ITapOFTv2.TwTapAlreadySet.selector);
        bTapOFT.setTwTAP(address(twTap));
    }

    /**
     * @dev Test the OApp functionality of `TapOFTv2.lockTwTapPosition()` function.
     */
    function test_lock_twTap_position() public {
        // lock info
        uint256 amountToSendLD = 1 ether;
        uint96 lockDuration = 80;

        LockTwTapPositionMsg
            memory lockTwTapPositionMsg = LockTwTapPositionMsg({
                user: address(this),
                duration: lockDuration,
                amount: amountToSendLD
            });

        // Prepare args call
        SendParam memory sendParam = SendParam({
            dstEid: bEid,
            to: OFTMsgCodec.addressToBytes32(address(this)),
            amountToSendLD: amountToSendLD,
            minAmountToCreditLD: amountToSendLD
        });

        bytes memory lockPosition = TapOFTMsgCoder.buildLockTwTapPositionMsg(
            lockTwTapPositionMsg
        );

        bytes memory composeOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, 1_000_000, 0);
        (bytes memory composeMsg, ) = aTapOFT.buildTapComposedMsg(
            lockPosition,
            PT_LOCK_TWTAP,
            0,
            sendParam.dstEid,
            composeOptions,
            bytes("") // Previous tapComposeMsg
        );

        bytes memory oftMsgOptions = OptionsBuilder.addExecutorLzReceiveOption(
            composeOptions,
            1_000_000,
            0
        );
        MessagingFee memory msgFee = aTapOFT.quoteSendPacket(
            sendParam,
            oftMsgOptions,
            false,
            composeMsg,
            ""
        );

        LZSendParam memory lzSendParam = LZSendParam({
            sendParam: sendParam,
            fee: msgFee,
            extraOptions: oftMsgOptions,
            refundAddress: address(this)
        });

        // Mint necessary tokens
        deal(address(aTapOFT), address(this), amountToSendLD);

        (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        ) = aTapOFT.sendPacket{value: msgFee.nativeFee}(
                lzSendParam,
                composeMsg
            );

        verifyPackets(
            uint32(bEid),
            OFTMsgCodec.addressToBytes32(address(bTapOFT))
        );

        vm.expectEmit(true, true, true, false);
        emit ITapOFTv2.LockTwTapReceived(
            lockTwTapPositionMsg.user,
            lockTwTapPositionMsg.duration,
            amountToSendLD
        );

        _callLzCompose(
            LzOFTComposedData(
                PT_LOCK_TWTAP,
                msgReceipt.guid,
                composeMsg,
                bEid,
                address(bTapOFT), // Compose creator (at lzReceive)
                address(bTapOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions
            )
        );
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
    function _callLzCompose(
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
}
