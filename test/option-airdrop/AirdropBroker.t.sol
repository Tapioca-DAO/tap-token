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

// Tapioca Tests
import {TapTestHelper} from "../TapTestHelper.t.sol";
import {ERC721Mock} from "../ERC721Mock.sol";
import {TapOFTV2Mock} from "../TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";

import {MockToken} from "gitsub_tapioca-sdk/src/contracts/mocks/MockToken.sol";

// Tapioca contracts
import {AOTAP} from "../../contracts/option-airdrop/AOTAP.sol";

// Import contract to test
import {AirdropBroker} from "../../contracts/option-airdrop/AirdropBroker.sol";
import {Errors} from "../helpers/errors.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract AirdropBrokerTest is TapTestHelper, Errors {
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
    uint256 public __governanceEid = aEid; //aEid, initially bEid
    address public __owner = address(this);

    function setUp() public override {
        vm.deal(owner, 1000 ether); //give owner some ether
        vm.deal(tokenBeneficiary, 1000 ether); //give tokenBeneficiary some ether
        vm.label(owner, "owner"); //label address for test traces
        vm.label(tokenBeneficiary, "tokenBeneficiary"); //label address for test traces

        setUpEndpoints(3, LibraryType.UltraLightNode); //TODO: check if this is necessary

        aTapOFT = TapOFTV2Mock(
            payable(
                _deployOApp(
                    type(TapOFTV2Mock).creationCode,
                    abi.encode(
                        address(endpoints[aEid]),
                        __contributors,
                        __earlySupporters,
                        __supporters,
                        __lbp,
                        __dao,
                        __airdrop,
                        __governanceEid,
                        address(this),
                        address(
                            new TapOFTSender(
                                address(endpoints[aEid]),
                                address(this)
                            )
                        ),
                        address(
                            new TapOFTReceiver(
                                address(endpoints[aEid]),
                                address(this)
                            )
                        )
                    )
                )
            )
        );
        vm.label(address(aTapOFT), "aTapOFT"); //label address for test traces

        erc721Mock = new ERC721Mock("MockERC721", "Mock"); //deploy ERC721Mock
        vm.label(address(erc721Mock), "erc721Mock"); //label address for test traces
        tapOFTv2Helper = new TapOFTv2Helper();
        tapOracleMock = new TapOracleMock();
        aotap = new AOTAP(address(this)); //deploy AOTAP and set address to owner

        airdropBroker = new AirdropBroker(
            address(aotap),
            payable(address(aTapOFT)),
            address(erc721Mock),
            tokenBeneficiary,
            address(owner)
        );

        vm.startPrank(owner);
        mockToken = new MockToken("MockERC20", "Mock"); //deploy MockToken
        vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        mockToken.transfer(address(this), 1_000_001 * 10 ** 18); //transfer some tokens to address(this)
        mockToken.transfer(address(airdropBroker), 333333 * 10 ** 18);
        bytes memory _data = abi.encode(uint256(1));

        erc721Mock.mint(address(owner), 1); //mint NFT id 1 to owner
        erc721Mock.mint(address(tokenBeneficiary), 2); //mint NFT id 2 to beneficiary
        airdropBroker.setTapOracle(tapOracleMock, _data);
        vm.stopPrank();

        // config and wire the ofts
        address[] memory ofts = new address[](1);
        ofts[0] = address(aTapOFT);
        this.wireOApps(ofts);

        super.setUp();
    }

    // vm.expectEmit(true, true, true, false);
    //  airdropBroker.epoch = 1;

    // bytes calldata _data = abi.encodePacked(
    //     airdropBroker.participate.selector,
    //     abi.encode()
    // );
    // THEN
    // vm.expectRevert(stdError.arithmeticError);
    // assertEq(address(aTapOFT), address(airdropBroker.tapOFT()), "tapOFT address should be set");
    // assertEq(address(aotap), address(airdropBroker.aotap()), "aotap address should be set");
    // assertEq(address(erc721Mock), address(airdropBroker.erc721()), "erc721 address should be set");
    // assertEq(address(owner), address(airdropBroker.owner()), "owner address should be set");
    // assertEq(address(tokenBeneficiary), address(airdropBroker.tokenBeneficiary()), "tokenBeneficiary address should be set");

    function test_cannot_participate_epoch_not_started() public {
        uint256[] memory _tokenID = new uint256[](2);
        _tokenID[0] = uint256(1);
        _tokenID[1] = uint256(2);

        bytes memory _data = abi.encode(_tokenID);

        vm.expectRevert(NotStarted.selector);
        airdropBroker.participate(_data);
    }

    // function test_cannot_participate_epoch_ended() public { //TODO

    // uint256[] memory _tokenID = new uint256[](2);
    // _tokenID[0] = uint256(1);
    // _tokenID[1] = uint256(2);
    // bytes memory _data = abi.encode(_tokenID);

    // uint256 timestamp = block.timestamp;

    // vm.warp(timestamp + 172810); //2 days in seconds + 10 seconds 172810 to increase the epoch
    // airdropBroker.newEpoch();

    // assertEq(airdropBroker.epoch(), 0);
    // airdropBroker.epoch = 9; //this is > LAST_EPOCH
    // assertEq(airdropBroker.epoch, 9);

    //wrap the estimated timestamp newEpoch()

    // Set block.timestamp
    // vm.store(address(airdropBroker), bytes32(uint256(5)), bytes32(uint256(9))); //epoch is in slot 5
    // bytes32 epoch = vm.load(address(airdropBroker), bytes32(uint256(5)));
    // emit log_uint(uint256(epoch));
    // uint256 e = airdropBroker.read_slot();
    // emit log_uint(uint256(e));

    // 9
    // vm.expectRevert(Ended.selector);
    // airdropBroker.participate(_data);

    // }

    function test_participate_phase_1_not_elegible() public {
        uint256[] memory _tokenID = new uint256[](2);
        _tokenID[0] = uint256(1);
        _tokenID[1] = uint256(2);
        bytes memory _data = abi.encode(_tokenID);

        vm.warp(block.timestamp + 172810); //2 days in seconds + 10 seconds 172810 to increase the epoch
        airdropBroker.newEpoch();

        vm.expectRevert(NotEligible.selector);
        airdropBroker.participate(_data);
    }

    // function test_participate_phase_1() public {

    //     uint256[] memory _tokenID = new uint256[](2);
    //     _tokenID[0] = uint256(1);
    //     _tokenID[1] = uint256(2);

    //     //TODO set the cachedEpoch = 1
    //     bytes memory _data = abi.encode(_tokenID);

    //     airdropBroker.participate(_data);
    //     //TODO NFT minted

    // }

    function test_participate_phase_2_not_elegible() public {
        //fail,encode better

        uint256[] memory _tokenID = new uint256[](2);
        _tokenID[0] = uint256(1);
        _tokenID[1] = uint256(2);

        bytes memory _data = abi.encode(_tokenID);

        //2 days in seconds + 10 seconds 172810 to increase the epoch
        for (uint256 i = 1; i < 3; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }
        //TODO: add expect emits to track the epochs better

        vm.expectRevert(NotEligible.selector);
        airdropBroker.participate(_data); //TODO: fix that it does not work due to a merkle proof and an incorrect bytes decoding on `_participatePhase2`
    }

    function test_participate_phase_2_only_broker() public {
        //fail for encoding
        vm.startPrank(owner);
        uint256[] memory _tokenID = new uint256[](1);
        _tokenID[0] = uint256(1);

        bytes memory _data = abi.encode(_tokenID);

        for (uint256 i = 1; i < 3; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        vm.expectRevert(OnlyBroker.selector);
        airdropBroker.participate(_data);
        vm.stopPrank();
    }

    function test_new_epoch_too_soon() public {
        uint256 timestamp = block.timestamp;
        vm.warp(timestamp + 172810); //2 days in seconds + 10 seconds 172810 to increase the epoch
        airdropBroker.newEpoch();

        vm.warp(timestamp + 172811); //only 1 second more to trigger revert
        vm.expectRevert(TooSoon.selector);
        airdropBroker.newEpoch();
    }

    // function test_participate_phase_2_already_participated() public {

    //     uint256[] memory _tokenID = new uint256[](2);
    //     _tokenID[0] = uint256(1);
    //     _tokenID[1] = uint256(2);

    //     //TODO set the cachedEpoch = 2
    //     bytes memory _data = abi.encode(_tokenID);

    //     vm.expectRevert(AlreadyParticipated.selector);
    //     airdropBroker.participate(_data);

    // }

    // function test_participate_phase_2() public {

    //     uint256[] memory _tokenID = new uint256[](2);
    //     _tokenID[0] = uint256(1);
    //     _tokenID[1] = uint256(2);

    //     //TODO set the cachedEpoch = 1
    //     bytes memory _data = abi.encode(_tokenID);

    //     airdropBroker.participate(_data);
    //     //TODO NFT minted

    // }

    function test_participate_phase_3_not_elegible() public {
        //ok

        uint256[] memory _tokenID = new uint256[](1);
        _tokenID[0] = uint256(2);

        bytes memory _data = abi.encode(_tokenID);

        for (uint256 i = 1; i < 4; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        vm.expectRevert(NotEligible.selector);
        airdropBroker.participate(_data);
    }

    function test_participate_phase_3_not_existent_nft() public {
        //ok

        uint256[] memory _tokenID = new uint256[](1);
        _tokenID[0] = uint256(11); //NOTE not existent tokenId

        bytes memory _data = abi.encode(_tokenID);

        for (uint256 i = 1; i < 4; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        vm.expectRevert(bytes("ERC721: invalid token ID"));
        airdropBroker.participate(_data);
    }

    function test_participate_phase_3_only_broker() public {
        //ok
        vm.startPrank(owner);
        uint256[] memory _tokenID = new uint256[](1);
        _tokenID[0] = uint256(1);

        bytes memory _data = abi.encode(_tokenID);

        for (uint256 i = 1; i < 4; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        vm.expectRevert(OnlyBroker.selector);
        airdropBroker.participate(_data);
        vm.stopPrank();
    }

    function test_dao_aoTAP_broker_claim() public {
        vm.startPrank(owner);
        airdropBroker.aoTAPBrokerClaim();
        vm.stopPrank();
    }

    function test_dao_aoTAP_broker_claim_only_once() public {
        vm.startPrank(owner);
        vm.expectRevert(OnlyOnce.selector);
        airdropBroker.aoTAPBrokerClaim();
        vm.stopPrank();
    }

    function test_participate_phase_3_already_participated() public {
        //fail
        vm.startPrank(owner);
        uint256[] memory _tokenID = new uint256[](1);
        _tokenID[0] = uint256(1);

        bytes memory _data = abi.encode(_tokenID);

        for (uint256 i = 1; i < 4; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        airdropBroker.participate(_data);
        // assertEq();
        vm.expectRevert(AlreadyParticipated.selector);
        airdropBroker.participate(_data);
        vm.stopPrank();
    }

    // function test_participate_phase_3() public {

    //     uint256[] memory _tokenID = new uint256[](2);
    //     _tokenID[0] = uint256(1);
    //     _tokenID[1] = uint256(2);

    //     //TODO set the cachedEpoch = 1
    //     bytes memory _data = abi.encode(_tokenID);

    //     airdropBroker.participate(_data);
    //     //TODO NFT minted

    // }

    // function test_participate_phase_4_not_elegible() public {

    //     uint256[] memory _tokenID = new uint256[](2);
    //     _tokenID[0] = uint256(1);
    //     _tokenID[1] = uint256(2);

    //     //TODO set the cachedEpoch = 2
    //     bytes memory _data = abi.encode(_tokenID);

    //     vm.expectRevert(NotEligible.selector);
    //     airdropBroker.participate(_data);

    // }

    // function test_participate_phase_3() public {

    //     uint256[] memory _tokenID = new uint256[](2);
    //     _tokenID[0] = uint256(1);
    //     _tokenID[1] = uint256(2);

    //     //TODO set the cachedEpoch = 1
    //     bytes memory _data = abi.encode(_tokenID);

    //     airdropBroker.participate(_data);
    //     //TODO NFT minted

    // }

    function test_airdrop_not_callable_when_paused() public {
        vm.startPrank(owner);
        // airdropBroker.pause(); //NOTE it seems like it can't be paused
        uint256[] memory _tokenID = new uint256[](2);
        _tokenID[0] = uint256(1);
        _tokenID[1] = uint256(2);
        bytes memory _data = abi.encode(_tokenID);

        vm.expectRevert(bytes("Pausable: paused"));
        airdropBroker.participate(_data);

        vm.stopPrank();
    }

    function test_dao_recover_tap_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        airdropBroker.daoRecoverTAP();
        vm.stopPrank();
    }

    function test_dao_recover_tap_before_end_epoch() public {
        vm.startPrank(owner);
        
        //advance 2 epochs
        for (uint256 i = 1; i < 3; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        vm.expectRevert(bytes("adb: too soon"));
        airdropBroker.daoRecoverTAP();
        vm.stopPrank();
    }

    function test_dao_recover_tap_transfer() public {//ok

        vm.startPrank(__earlySupporters);

        //transfer tokens to the airdropBroker contract

        uint256 _balance = aTapOFT.balanceOf(address(__earlySupporters)); 

        aTapOFT.transfer(address(airdropBroker), _balance);

        vm.stopPrank();

        vm.startPrank(owner);

        //deal balance to airdropBroker of tapOFT
        uint256 balance = aTapOFT.balanceOf(address(airdropBroker));

        for (uint256 i = 1; i < 11; i++) {
            //move 9 epochs in the future
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        uint256 balanceBeforeAirdrop = aTapOFT.balanceOf(
            address(airdropBroker)
        );
        uint256 balanceBeforeOwner = aTapOFT.balanceOf(address(owner));
        airdropBroker.daoRecoverTAP();
        uint256 balanceAfterAirdrop = aTapOFT.balanceOf(address(airdropBroker));
        uint256 balanceAfterOwner = aTapOFT.balanceOf(address(owner));
        assertEq(
            balanceBeforeAirdrop + balanceBeforeOwner,
            balanceAfterOwner + balanceAfterAirdrop
        ); //NOTE this is counting no fee-on-transfer tokens
        assertEq(balanceAfterOwner, balanceBeforeOwner + balanceBeforeAirdrop);
        assertEq(balanceAfterAirdrop, 0);

        vm.stopPrank();
    }

    function increase_epochs() internal {}

    function test_set_tap_oracle_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        bytes memory _data = abi.encode(uint256(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        airdropBroker.setTapOracle(tapOracleMock, _data);
        vm.stopPrank();
    }

    function test_set_phase_2merkle_roots_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        bytes32[4] memory _merkleRoots;
        _merkleRoots[0] = bytes32("0x01");
        _merkleRoots[1] = bytes32("0x02");
        _merkleRoots[2] = bytes32("0x03");
        _merkleRoots[3] = bytes32("0x04");
        bytes memory _data = abi.encode(_merkleRoots);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        airdropBroker.setPhase2MerkleRoots(_merkleRoots);
        vm.stopPrank();
    }

    function test_register_users_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        address[] memory users = new address[](2);
        users[0] = address(0x01);
        users[1] = address(0x02);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = uint256(1);
        amounts[1] = uint256(2);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        airdropBroker.registerUsersForPhase(1, users, amounts);
        vm.stopPrank();
    }

    function test_register_users_different_lengths() public {
        //ok

        vm.startPrank(owner);

        address[] memory users = new address[](2);
        users[0] = address(0x01);
        users[1] = address(0x02);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = uint256(1);
        vm.expectRevert(NotValid.selector);
        airdropBroker.registerUsersForPhase(1, users, amounts);
        vm.stopPrank();
    }

    // function test_set_payment_token_not_owner() public {

    //     vm.startPrank(tokenBeneficiary);
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     airdropBroker.setPaymentToken(ERC20(aTapOFT),tapOracleMock,"");
    //     vm.stopPrank();

    // }

    function test_payment_token_benficiary_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        address user1 = address(0x01);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        airdropBroker.setPaymentTokenBeneficiary(user1);
        vm.stopPrank();
    }

    function test_collect_payment_tokens_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        address[] memory tokens = new address[](2);
        tokens[0] = address(0x01);
        tokens[1] = address(0x02);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        airdropBroker.collectPaymentTokens(tokens);
        vm.stopPrank();
    }

    function test_beneficiary_not_set() public {
        //ok

        vm.startPrank(owner);
        airdropBroker.setPaymentTokenBeneficiary(address(0x0)); //set address to 0
        address[] memory tokens = new address[](2);
        tokens[0] = address(0x01);
        tokens[1] = address(0x02);
        vm.expectRevert(TokenBeneficiaryNotSet.selector);
        airdropBroker.collectPaymentTokens(tokens);
        vm.stopPrank();
    }

    function test_collect_payments() public {
        //ok

        vm.startPrank(owner);
        airdropBroker.setPaymentTokenBeneficiary(address(owner));
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);
        //check balances of tokens before and after
        uint256 balanceBeforeAirdrop = mockToken.balanceOf(
            address(airdropBroker)
        );
        uint256 balanceBeforeOwner = mockToken.balanceOf(address(owner));
        airdropBroker.collectPaymentTokens(tokens);
        uint256 balanceAfterAirdrop = mockToken.balanceOf(
            address(airdropBroker)
        );
        uint256 balanceAfterOwner = mockToken.balanceOf(address(owner));
        assertEq(
            balanceBeforeAirdrop + balanceBeforeOwner,
            balanceAfterOwner + balanceAfterAirdrop
        ); //NOTE this is counting no fee-on-transfer tokens
        assertEq(balanceAfterOwner, balanceBeforeOwner + balanceBeforeAirdrop);
        assertEq(balanceAfterAirdrop, 0);
        vm.stopPrank();
    }

    // function test_non_reentrant()public{

    //     vm.startPrank(owner);
    //     vm.stopPrank();

    // }

    // function test_RevertWhen_CallerIsNotOwner() public {
    //         vm.expectRevert(Unauthorized.selector);
    //         vm.prank(address(0));
    //         upOnly.increment();
    //     }

    //     function test_ExpectEmit_DoNotCheckData() public {
    //         ExpectEmit emitter = new ExpectEmit();
    //         // Check topic 1 and topic 2, but do not check data
    //         vm.expectEmit(true, true, false, false);
    //         // The event we expect
    //         emit Transfer(address(this), address(1337), 1338);
    //         // The event we get
    //         emitter.t();
    //     }

    // }

    // function test_brokerClaim() public {
    // GIVEN
    // WHEN
    // airdropBroker.brokerClaim();
    // // THEN
    // assertEq(address(aTapOFT), address(airdropBroker.broker()), "broker address should be set");
    // }
}
