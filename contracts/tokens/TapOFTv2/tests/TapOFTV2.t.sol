// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

import "forge-std/Test.sol";

import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

import {TestHelper} from "./mocks/TestHelper.sol";

import {LZSendParam, LockTwTapPositionMsg} from "../ITapOFTv2.sol";
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

    uint16 internal constant PT_LOCK_TWTAP = 870;
    uint16 internal constant PT_UNLOCK_TWTAP = 871;
    uint16 internal constant PT_CLAIM_REWARDS = 872;

    function setUp() public override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        setUpEndpoints(3, LibraryType.UltraLightNode);

        aTapOFT = TapOFTV2Mock(
            _deployOApp(
                type(TapOFTV2Mock).creationCode,
                abi.encode(address(endpoints[aEid]), address(this))
            )
        );
        vm.label(address(aTapOFT), "aTapOFT");
        bTapOFT = TapOFTV2Mock(
            _deployOApp(
                type(TapOFTV2Mock).creationCode,
                abi.encode(address(endpoints[bEid]), address(this))
            )
        );
        vm.label(address(bTapOFT), "bTapOFT");

        // config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(aTapOFT);
        ofts[1] = address(bTapOFT);
        this.wireOApps(ofts);
    }

    function test_constructor() public {
        assertEq(aTapOFT.owner(), address(this));
        assertEq(bTapOFT.owner(), address(this));

        assertEq(aTapOFT.token(), address(aTapOFT));
        assertEq(bTapOFT.token(), address(bTapOFT));
    }

    event OFTReceived(bytes32, address, uint256, uint256);

    function test_lock_twTap_position() public {
        // lock info
        uint256 amountToSendLD = 1 ether;
        uint256 lockDuration = 80;

        LockTwTapPositionMsg
            memory lockTwTapPositionMsg = LockTwTapPositionMsg({
                user: address(this),
                duration: lockDuration
            });

        // Prepare args call
        SendParam memory sendParam = SendParam({
            dstEid: bEid,
            to: OFTMsgCodec.addressToBytes32(address(this)),
            amountToSendLD: amountToSendLD,
            minAmountToCreditLD: amountToSendLD
        });
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(1_000_000, 0)
            .addExecutorLzComposeOption(0, 1_000_000, 0); // 100k gas, 0 value // index 0, 100k gas, 0 value

        bytes memory lockPosition = aTapOFT.buildLockTwTapPositionMsg(
            lockTwTapPositionMsg
        );

        (bytes memory composeMsg, ) = aTapOFT.buildMsgAndOptionsByType(
            PT_LOCK_TWTAP,
            sendParam,
            extraOptions,
            lockPosition,
            amountToSendLD
        );
        MessagingFee memory msgFee = aTapOFT.quoteSendPacket(
            PT_LOCK_TWTAP,
            sendParam,
            extraOptions,
            false,
            composeMsg,
            ""
        );
        LZSendParam memory lzSendParam = LZSendParam({
            _sendParam: sendParam,
            _fee: msgFee,
            _extraOptions: extraOptions,
            refundAddress: address(this)
        });

        // Mint necessary tokens
        deal(address(aTapOFT), address(this), amountToSendLD);

        (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt
        ) = aTapOFT.lockTwTapPosition{value: msgFee.nativeFee}(
                lzSendParam,
                lockPosition
            );
        // vm.expectEmit(false, true, true, true);
        // emit OFTReceived(
        //     bytes32(0),
        //     address(this),
        //     amountToSendLD,
        //     amountToSendLD
        // );

        // verifyPackets(
        //     uint32(bEid),
        //     OFTMsgCodec.addressToBytes32(address(bTapOFT)),
        //     0,
        //     address(bTapOFT)
        // );
        verifyPackets(
            uint32(bEid),
            OFTMsgCodec.addressToBytes32(address(bTapOFT))
        );
        bytes memory composedMsg = abi.encodePacked(
            PT_LOCK_TWTAP,
            lockPosition
        );
        _callLzCompose(
            msgReceipt,
            oftReceipt,
            aEid,
            bEid,
            address(bTapOFT),
            extraOptions,
            msgReceipt.guid,
            address(bTapOFT),
            address(this),
            composeMsg
        );
    }

    function _callLzCompose(
        MessagingReceipt memory msgReceipt,
        OFTReceipt memory oftReceipt,
        uint32 srcEid_,
        uint32 dstEid_,
        address from_,
        bytes memory options_,
        bytes32 guid_,
        address to_,
        address caller_,
        bytes memory composeMsg
    ) internal {
        address oftSendTo_ = address(this);

        // Remove the prepend that OFTMsgCodec.encode adds on a composed message to get the actual OApp compose msg
        bytes memory composeMsgWithoutToAddress = BytesLib.slice(
            composeMsg,
            40,
            composeMsg.length - 40
        );
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            msgReceipt.nonce,
            srcEid_,
            oftReceipt.amountCreditLD,
            composeMsgWithoutToAddress
        );
        console.log("2");
        // console.log(oftReceipt.amountCreditLD);
        // console.log(oftSendTo_);
        console.logBytes(composerMsg_);
        console.log("");
        // console.logBytes(composerMsg_);
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);
    }
}
