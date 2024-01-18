// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// LZ
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//Tapioca
import {ITapOFTv2, LockTwTapPositionMsg, UnlockTwTapPositionMsg, LZSendParam, ERC20PermitStruct, ERC721PermitStruct, ERC20PermitApprovalMsg, ERC721PermitApprovalMsg, ClaimTwTapRewardsMsg, RemoteTransferMsg} from "@contracts/tokens/TapOFTv2/ITapOFTv2.sol";
import {TapOFTv2Helper, PrepareLzCallData, PrepareLzCallReturn, ComposeMsgData} from "@contracts/tokens/TapOFTv2/extensions/TapOFTv2Helper.sol";
import {TapOFTMsgCoder} from "@contracts/tokens/TapOFTv2/TapOFTMsgCoder.sol";
import {TwTAP, Participation} from "@contracts/governance/twTAP.sol";
import {TapOFTReceiver} from "@contracts/tokens/TapOFTv2/TapOFTReceiver.sol";
import {TapOFTSender} from "@contracts/tokens/TapOFTv2/TapOFTSender.sol";

import {MockToken} from "gitsub_tapioca-sdk/src/contracts/mocks/MockToken.sol";

// Tapioca Tests
import {TapTestHelper} from "../TapTestHelper.t.sol";
import {ERC721Mock} from "../ERC721Mock.sol";
import {TapOFTV2Mock} from "../TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";

// Tapioca contracts
import {AOTAP} from "../../contracts/option-airdrop/AOTAP.sol";

// Import contract to test
import {AirdropBroker} from "../../contracts/option-airdrop/AirdropBroker.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract aoTapTest is TapTestHelper {
    using stdStorage for StdStorage;

    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    TapOFTv2Helper public tapOFTv2Helper; //instance of TapOFTv2Helper
    TapOFTV2Mock public aTapOFT; //instance of TapOFTV2Mock
    TapOFTV2Mock public bTapOFT; //instance of TapOFTV2Mock NOTE unused to the moment
    AirdropBroker public airdropBroker; //instance of AirdropBroker
    TapOracleMock public tapOracleMock; //instance of TapOracleMock
    MockToken public mockToken; //instance of MockToken (erc20)
    ERC721Mock public erc721Mock; //instance of ERC721Mock
    AOTAP public aotap; //instance of AOTAP

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public owner = vm.addr(userAPKey);
    address public tokenBeneficiary = vm.addr(userBPKey);

    /**
     * DEPLOY setup addresses
     */
    address public __endpoint;
    address public __contributors = address(0x30);
    address public __earlySupporters = address(0x31);
    address public __supporters = address(0x32);
    address public __lbp = address(0x33);
    address public __dao = address(0x34);
    address public __airdrop = address(0x35);
    uint256 public __governanceEid = 0; //aEid, initially bEid
    address public __owner = address(this);

    //TODO: Modularize all the errors in one file and import
    error PaymentTokenNotValid();
    error OptionExpired();
    error TooHigh();
    error TooLow();
    error NotStarted();
    error Ended();
    error NotAuthorized();
    error TooSoon();
    error Failed();
    error NotValid();
    error TokenBeneficiaryNotSet();
    error NotEligible();
    error AlreadyParticipated();
    error PaymentAmountNotValid();
    error TapAmountNotValid();
    error PaymentTokenValuationNotValid();
    error OnlyBroker();
    error OnlyOnce();

    function setUp() public override {
        vm.deal(owner, 1000 ether); //give owner some ether
        vm.deal(tokenBeneficiary, 1000 ether); //give tokenBeneficiary some ether
        vm.label(owner, "owner"); //label address for test traces
        vm.label(tokenBeneficiary, "tokenBeneficiary"); //label address for test traces

        aotap = new AOTAP(address(owner)); //deploy AOTAP and set address to owner

        // config and wire the ofts
        address[] memory ofts = new address[](1);
        ofts[0] = address(aTapOFT);
        this.wireOApps(ofts);

        super.setUp();
    }

    function test_cannot_mint_no_broker() public {
        vm.expectRevert(OnlyBroker.selector);
        aotap.mint(address(owner), 1, 1, 1);
    }

    function test_mint_aoTAP() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint256 tokenId = aotap.mint(address(owner), 1, 1, 1);
        uint256 balance = aotap.balanceOf(address(owner));
        assertEq(balance, 1);
        vm.stopPrank();
    }

    function test_mint_several_aoTAP() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint i;
        for (i; i < 10; i++) {
            uint256 tokenId = aotap.mint(address(owner), 1, 1, 1);
            uint256 balance = aotap.balanceOf(address(owner));
            assertEq(balance, i + 1);
        }
        uint256 _balance = aotap.balanceOf(address(owner));
        assertEq(_balance, i);
        vm.stopPrank();
    }

    function test_transfer_from() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        aotap.safeTransferFrom(owner, tokenBeneficiary, 1);
        address new_owner = aotap.ownerOf(1);
        assertEq(tokenBeneficiary, new_owner);
        uint bal = aotap.balanceOf(tokenBeneficiary);
        assertEq(bal, 1);
        vm.stopPrank();
    }

    function test_burn() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        aotap.burn(1);
        uint bal = aotap.balanceOf(owner);
        assertEq(bal, (0));
        vm.stopPrank();
    }

    function test_fail_burning() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        vm.stopPrank();
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(NotAuthorized.selector);
        aotap.burn(1);
        vm.stopPrank();
    }

    function test_approvals() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        aotap.approve(tokenBeneficiary, 1);
        address _owner = aotap.ownerOf(1);
        assertEq(owner, _owner);
        address _approved = aotap.getApproved(1);
        assertEq(tokenBeneficiary, _approved);
        vm.stopPrank();
    }

    function test_get_approved() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        aotap.approve(tokenBeneficiary, 1);
        address _approved = aotap.getApproved(1);
        assertEq(_approved, tokenBeneficiary);
        vm.stopPrank();
    }

    function test_set_approval_for_all() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        aotap.setApprovalForAll(tokenBeneficiary, true);
        bool _approved = aotap.isApprovedForAll(owner, tokenBeneficiary);
        assertEq(_approved, true);
        vm.stopPrank();
    }

    // Testing of events

    function testTransferEvent() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        vm.expectEmit(true, true, true, false);
        // emit Transfer(owner,tokenBeneficiary,1);
        aotap.safeTransferFrom(owner, tokenBeneficiary, 1);
        vm.stopPrank();
    }

    function testApprovalEvent() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        vm.expectEmit(true, true, true, false);
        // emit Approval(owner,tokenBeneficiary,1);
        aotap.approve(tokenBeneficiary, 1);
        vm.stopPrank();
    }

    function testApprovalForAllEvent() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        aotap.mint(owner, 1, 1, 1);
        vm.expectEmit(true, true, true, false);
        // emit ApprovalForAll(owner,tokenBeneficiary,true);
        aotap.setApprovalForAll(tokenBeneficiary, true);
        vm.stopPrank();
    }
}
