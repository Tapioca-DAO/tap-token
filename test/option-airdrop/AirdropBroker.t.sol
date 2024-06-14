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

import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//Tapioca
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
} from "contracts/tokens/ITapToken.sol";
import {
    TapTokenHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "contracts/tokens/extensions/TapTokenHelper.sol";
import {TapTokenCodec} from "contracts/tokens/TapTokenCodec.sol";
import {TwTAP, Participation} from "contracts/governance/twTAP.sol";
import {TapTokenReceiver} from "contracts/tokens/TapTokenReceiver.sol";
import {TapTokenSender} from "contracts/tokens/TapTokenSender.sol";
import {IPearlmit, Pearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {ICluster, Cluster} from "tapioca-periph/Cluster/Cluster.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";

// Tapioca Tests

import {TapTestHelper} from "../helpers/TapTestHelper.t.sol";
import {ERC721Mock} from "../Mocks/ERC721Mock.sol";
import {TapTokenMock as TapOFTV2Mock} from "../Mocks/TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";
import {ITapiocaOracle} from "tapioca-periph/interfaces/periph/ITapiocaOracle.sol";

import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

// Tapioca contracts
import {AOTAP} from "contracts/option-airdrop/AOTAP.sol";

// Import contract to test
import {AirdropBroker} from "contracts/option-airdrop/AirdropBroker.sol";
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

    TapTokenHelper public tapTokenHelper; //instance of TapTokenHelper
    TapOFTV2Mock public aTapOFT; //instance of TapOFTV2Mock
    TapOFTV2Mock public bTapOFT; //instance of TapOFTV2Mock NOTE unused to the moment
    AirdropBroker public airdropBroker; //instance of AirdropBroker
    TapOracleMock public tapOracleMock; //instance of TapOracleMock
    ERC20Mock public mockToken; //instance of ERC20Mock (erc20)
    ERC721Mock public erc721Mock; //instance of ERC721Mock
    AOTAP public aotap; //instance of AOTAP
    TapiocaOmnichainExtExec extExec; //instance of TapiocaOmnichainExtExec
    Pearlmit pearlmit;
    Cluster cluster;

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public owner = vm.addr(userAPKey);
    address public tokenBeneficiary = vm.addr(userBPKey);
    uint256 public EPOCH_DURATION = 7 days;
    uint32 public lzChainId = 1;

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

        extExec = new TapiocaOmnichainExtExec();
        pearlmit = new Pearlmit("Pearlmit", "1", owner, type(uint256).max); // NOTE: setting nativeValueToCheckPauseState in Pearlmit to max to avoid potentially setting pause state unintentionally
        cluster = new Cluster(lzChainId, owner); // NOTE: setting lzChainId arg here to 1, unsure if this is correct
        aTapOFT = new TapOFTV2Mock(
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
                owner,
                address(new TapTokenSender("", "", address(endpoints[aEid]), address(this), address(0))),
                address(new TapTokenReceiver("", "", address(endpoints[aEid]), address(this), address(0))),
                address(extExec),
                IPearlmit(address(pearlmit)),
                ICluster(address(cluster))
            )
        );
        vm.label(address(aTapOFT), "aTapOFT"); //label address for test traces

        erc721Mock = new ERC721Mock("MockERC721", "Mock"); //deploy ERC721Mock
        vm.label(address(erc721Mock), "erc721Mock"); //label address for test traces
        tapTokenHelper = new TapTokenHelper();
        tapOracleMock = new TapOracleMock();
        aotap = new AOTAP(IPearlmit(address(pearlmit)), owner); //deploy AOTAP and set address to owner

        airdropBroker = new AirdropBroker(
            address(aotap), address(erc721Mock), tokenBeneficiary, IPearlmit(address(pearlmit)), address(owner)
        );

        vm.startPrank(owner);
        mockToken = new ERC20Mock("MockERC20", "Mock"); //deploy ERC20Mock
        vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        mockToken.mint(address(this), 1_000_001 * 10 ** 18); //transfer some tokens to address(this)
        mockToken.mint(address(airdropBroker), 333333 * 10 ** 18);
        bytes memory _data = abi.encode(uint256(1));

        erc721Mock.mint(address(owner), 1); //mint NFT id 1 to owner
        erc721Mock.mint(address(tokenBeneficiary), 2); //mint NFT id 2 to beneficiary
        airdropBroker.setTapOracle(tapOracleMock, _data);
        airdropBroker.setTapToken(payable(address(aTapOFT)));
        vm.stopPrank();

        // config and wire the ofts
        address[] memory ofts = new address[](1);
        ofts[0] = address(aTapOFT);
        this.wireOApps(ofts);

        super.setUp();
    }

    function test_cannot_participate_epoch_not_started() public {
        uint256[] memory _tokenID = new uint256[](2);
        _tokenID[0] = uint256(1);
        _tokenID[1] = uint256(2);

        bytes memory _data = abi.encode(_tokenID);

        vm.expectRevert(NotStarted.selector);
        airdropBroker.participate(_data);
    }

    function test_participate_phase_1_not_elegible() public {
        vm.startPrank(owner);
        uint256[] memory _tokenID = new uint256[](2);
        _tokenID[0] = uint256(1);
        _tokenID[1] = uint256(2);
        bytes memory _data = abi.encode(_tokenID);

        vm.warp(block.timestamp + 172810); //2 days in seconds + 10 seconds 172810 to increase the epoch
        airdropBroker.newEpoch();

        vm.expectRevert(NotEligible.selector);
        airdropBroker.participate(_data);
        vm.stopPrank();
    }

    function test_new_epoch_too_soon() public {
        vm.startPrank(owner);
        vm.warp(block.timestamp + 172810); //2 days in seconds + 10 seconds 172810 to increase the epoch
        airdropBroker.newEpoch();

        vm.warp(block.timestamp + 1); //only 1 second more to trigger revert
        vm.expectRevert(TooSoon.selector);
        airdropBroker.newEpoch();
        vm.stopPrank();
    }

    function test_participate_phase_3_not_elegible() public {
        //ok
        vm.startPrank(owner);
        uint256[] memory _tokenID = new uint256[](1);
        _tokenID[0] = uint256(2);

        bytes memory _data = abi.encode(_tokenID);

        for (uint256 i = 1; i < 4; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        vm.expectRevert(NotEligible.selector);
        airdropBroker.participate(_data);
        vm.stopPrank();
    }

    function test_participate_phase_3_not_existent_nft() public {
        //ok
        vm.startPrank(owner);
        uint256[] memory _tokenID = new uint256[](1);
        _tokenID[0] = uint256(11); //NOTE not existent tokenId

        bytes memory _data = abi.encode(_tokenID);

        for (uint256 i = 1; i < 4; i++) {
            vm.warp(block.timestamp + 172810 * i);
            airdropBroker.newEpoch();
        }

        vm.expectRevert(bytes("ERC721: invalid token ID"));
        airdropBroker.participate(_data);
        vm.stopPrank();
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

        vm.expectRevert(TooSoon.selector);
        airdropBroker.daoRecoverTAP();
        vm.stopPrank();
    }

    function test_dao_recover_tap_transfer() public {
        //ok
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

        uint256 balanceBeforeAirdrop = aTapOFT.balanceOf(address(airdropBroker));
        uint256 balanceBeforeOwner = aTapOFT.balanceOf(address(owner));
        airdropBroker.daoRecoverTAP();
        uint256 balanceAfterAirdrop = aTapOFT.balanceOf(address(airdropBroker));
        uint256 balanceAfterOwner = aTapOFT.balanceOf(address(owner));
        assertEq(balanceBeforeAirdrop + balanceBeforeOwner, balanceAfterOwner + balanceAfterAirdrop, "gain of value"); //NOTE this is counting no fee-on-transfer tokens
        assertEq(balanceAfterOwner, balanceBeforeOwner + balanceBeforeAirdrop, "owner balance after airdrop incorrect");
        assertEq(balanceAfterAirdrop, 0, "balance after airdrop is nonzero");

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

    function test_set_tap_oracle() public {
        //ok
        vm.startPrank(owner);
        bytes memory _data = abi.encode(uint256(2));
        airdropBroker.setTapOracle(tapOracleMock, _data);
        ITapiocaOracle _oracle = airdropBroker.tapOracle();
        bytes memory data = airdropBroker.tapOracleData();
        assertEq(address(_oracle), address(tapOracleMock));
        assertEq(data, _data);
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

    function test_payment_token_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        address user1 = address(0x01);
        bytes memory _data = abi.encode(uint256(3));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        airdropBroker.setPaymentToken((mockToken), ITapiocaOracle(tapOracleMock), _data);
        vm.stopPrank();
    }

    function test_payment_token() public {
        //ok
        vm.startPrank(owner);
        bytes memory _data = abi.encode(uint256(3));
        airdropBroker.setPaymentToken((mockToken), ITapiocaOracle(tapOracleMock), _data);
        ITapiocaOracle _oracle = airdropBroker.tapOracle();
        bytes memory data = airdropBroker.tapOracleData();
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
        uint256 balanceBeforeAirdrop = mockToken.balanceOf(address(airdropBroker));
        uint256 balanceBeforeOwner = mockToken.balanceOf(address(owner));
        airdropBroker.collectPaymentTokens(tokens);
        uint256 balanceAfterAirdrop = mockToken.balanceOf(address(airdropBroker));
        uint256 balanceAfterOwner = mockToken.balanceOf(address(owner));
        assertEq(balanceBeforeAirdrop + balanceBeforeOwner, balanceAfterOwner + balanceAfterAirdrop); //NOTE this is counting no fee-on-transfer tokens
        assertEq(balanceAfterOwner, balanceBeforeOwner + balanceBeforeAirdrop);
        assertEq(balanceAfterAirdrop, 0);
        vm.stopPrank();
    }
}
