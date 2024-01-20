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

contract twTAPTest is TapTestHelper, Errors {
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

    TwTAP public twTAP; //instance of TwTAP

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

        twTAP = new TwTAP(payable(address(aTapOFT)), address(owner));

        // config and wire the ofts
        address[] memory ofts = new address[](1);
        ofts[0] = address(aTapOFT);
        this.wireOApps(ofts);

        super.setUp();
    }

    function test_constructor() public {
        //ok
        assertEq(twTAP.owner(), address(owner));
        // assertEq(twTAP.tapOFT(), aTapOFT);
        assertEq(twTAP.creation(), block.timestamp);
        assertEq(twTAP.maxRewardTokens(), 1000);
    }

    function test_participation_1_day() public {
        //ok
        vm.startPrank(owner);
        vm.expectRevert(LockNotAWeek.selector);
        twTAP.participate(address(owner), 100 ether, 86400);
        //make sure no NFT has been minted
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        address _owner = twTAP.ownerOf(1);
        vm.stopPrank();
    }

    function test_participate_with_magnitude() public {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);
        aTapOFT.approve(address(twTAP), type(uint256).max);
        vm.expectRevert(NotValid.selector);
        twTAP.participate(address(owner), 100 ether, 1000 weeks);
        //make sure no NFT has been minted
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        address _owner = twTAP.ownerOf(1);
        vm.stopPrank();
    }

    function test_participate() public {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);
        aTapOFT.approve(address(twTAP), type(uint256).max);
        twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));
        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));
        vm.stopPrank();
    }

    function test_paused() public {
        //not
        vm.startPrank(owner);
        twTAP.participate(address(owner), 100 ether, 86400);
        twTAP.claimRewards(1, address(owner));
        vm.stopPrank();
    }

    function test_claim_not_approved() public {
        //ok
        vm.startPrank(owner);
        twTAP.addRewardToken(IERC20(mockToken));
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
        assertEq(length, 2);

        bytes memory data = abi.encode(tokens[1]);
        bytes memory data2 = abi.encode(mockToken);
        assertEq(data, data2);

        uint256 balanceBefore = IERC20(mockToken).balanceOf(address(owner));
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        twTAP.claimRewards(1, address(owner));

        uint256 balanceAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceBefore, balanceAfter);

        vm.stopPrank();
    }

    function test_claim_rewards() public {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);
        aTapOFT.approve(address(twTAP), type(uint256).max);
        twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));

        //add reward token
        twTAP.addRewardToken(IERC20(mockToken));
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
        assertEq(length, 2);

        bytes memory data = abi.encode(tokens[1]);
        bytes memory data2 = abi.encode(mockToken);
        assertEq(data, data2);

        uint256 balanceBefore = IERC20(mockToken).balanceOf(address(owner));
        uint256[] memory amounts_ = twTAP.claimRewards(1, address(owner));
        uint256 balanceAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceAfter, balanceBefore + amounts_[1]);

        vm.stopPrank();
    }

    function test_set_max_tokens_length_not_owner() public {
        //ok
        vm.startPrank(__earlySupporters);
        uint maxRewardTokensBefore = twTAP.maxRewardTokens();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        twTAP.setMaxRewardTokensLength(30);
        uint maxRewardTokensAfter = twTAP.maxRewardTokens();
        assertEq(maxRewardTokensBefore, maxRewardTokensAfter);
        vm.stopPrank();
    }

    function test_set_max_tokens_length() public {
        //ok
        vm.startPrank(owner);
        uint maxRewardTokens = twTAP.maxRewardTokens();
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        // vm.expectEmit(address(twTAP));
        // emit twTAP.LogMaxRewardsLength(maxRewardTokens, 30, length);
        twTAP.setMaxRewardTokensLength(30);
        assertEq(twTAP.maxRewardTokens(), 30);

        vm.stopPrank();
    }

    function test_register_twice_reward_token() public {
        //ok
        vm.startPrank(owner);
        twTAP.addRewardToken(IERC20(mockToken));
        vm.expectRevert(Registered.selector);
        twTAP.addRewardToken(IERC20(mockToken));
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        //length has to be 2 because we push on the constructor
        assertEq(length, 2);
        vm.stopPrank();
    }

    function test_add_max_reward_token() public {
        //ok
        vm.startPrank(owner);
        address tokenB = address(uint160(0x08));
        twTAP.setMaxRewardTokensLength(2);
        twTAP.addRewardToken(IERC20(mockToken));
        vm.expectRevert(TokenLimitReached.selector);
        twTAP.addRewardToken(IERC20(tokenB));
        vm.stopPrank();
    }

    function test_add_reward_token_not_owner() public {
        //ok
        vm.startPrank(__earlySupporters);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        twTAP.addRewardToken(IERC20(mockToken));
        //check token has indeed not been added
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        assertEq(length, 1);
        vm.stopPrank();
    }

    function test_add_reward_token() public {
        //ok
        vm.startPrank(owner);
        twTAP.addRewardToken(IERC20(mockToken));
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
        assertEq(length, 2);
        //assertEq does not work with addresses or types, so we have to cast it to bytes
        bytes memory data = abi.encode(tokens[1]);
        bytes memory data2 = abi.encode(mockToken);
        assertEq(data, data2);
        vm.stopPrank();
    }

    function test_distribute_rewards_on_different_weeks() public {
        //ok
        vm.startPrank(owner);

        twTAP.addRewardToken(IERC20(mockToken));
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
        assertEq(length, 2);

        bytes memory data = abi.encode(tokens[1]);
        bytes memory data2 = abi.encode(mockToken);
        assertEq(data, data2);

        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        IERC20(mockToken).approve(address(twTAP), type(uint256).max);

        uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(
            address(owner)
        );
        // vm.expectRevert(bytes("0x12"));ß
        vm.expectRevert(AdvanceWeekFirst.selector);
        twTAP.distributeReward(1, 1);
        uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceOwnerAfter, balanceOwnerBefore);

        vm.stopPrank();
    }

    function test_distribute_rewards_no_amount() public {
  //ok
        vm.startPrank(owner);

        //add rewards tokens
        twTAP.addRewardToken(IERC20(mockToken));
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
        assertEq(length, 2);

        bytes memory data = abi.encode(tokens[1]);
        bytes memory data2 = abi.encode(mockToken);
        assertEq(data, data2);

        //participate
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);

        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);

        aTapOFT.approve(address(twTAP), type(uint256).max);

        twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

        uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
        assertEq(balanceTwTAP, 100 ether);

        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));

        //advance a week
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        twTAP.advanceWeek(100);
        assertEq(twTAP.lastProcessedWeek(), 1);

        //distribute rewards
        IERC20(mockToken).approve(address(twTAP), type(uint256).max);

        uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(
            address(owner)
        );
        vm.expectRevert(NotValid.selector);
        twTAP.distributeReward(1, 0);
        uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceOwnerAfter, balanceOwnerBefore);

        vm.stopPrank();
    }

    function test_distribute_rewards() public {
        //ok
        vm.startPrank(owner);

        //add rewards tokens
        twTAP.addRewardToken(IERC20(mockToken));
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
        assertEq(length, 2);

        bytes memory data = abi.encode(tokens[1]);
        bytes memory data2 = abi.encode(mockToken);
        assertEq(data, data2);

        //participate
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);

        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);

        aTapOFT.approve(address(twTAP), type(uint256).max);

        twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

        uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
        assertEq(balanceTwTAP, 100 ether);

        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));

        //advance a week
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        twTAP.advanceWeek(100);
        assertEq(twTAP.lastProcessedWeek(), 1);

        //distribute rewards
        IERC20(mockToken).approve(address(twTAP), type(uint256).max);
        //NOTE if this is called before nothing is done, there will be a panic error when
        //dividing (_amount * DIST_PRECISION) / uint256(totals.netActiveVotes), as the denominator will be 0

        //NOTE so cool thing is that netActiveVotes is incremented in the new week when you participate therefore if you participate and try and claim before a week has passed, you will get a panic revert
        //weekTotals[w0 + 1].netActiveVotes += int256(votes);

        uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(
            address(owner)
        );
        twTAP.distributeReward(1, 1);
        uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceOwnerAfter, balanceOwnerBefore - 1);

        vm.stopPrank();
    }

    function test_advance_week() public {
        //ok
        vm.startPrank(owner);
        uint256 currentWeek = twTAP.currentWeek(); //0
        //warp 7 days + 1 second to satisfy the next epoch
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        twTAP.advanceWeek(100);
        assertEq(twTAP.lastProcessedWeek(), 1); //0
        vm.stopPrank();
    }

    function test_advance_week_multiple() public {
        //ok
        vm.startPrank(owner);
        uint256 currentWeek = twTAP.currentWeek(); //0
        //warp 7 days + 1 second to satisfy the next epoch
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        twTAP.advanceWeek(100);
        //warped so 1
        assertEq(twTAP.lastProcessedWeek(), 1);
        vm.warp(block.timestamp + 1 weeks);
        twTAP.advanceWeek(30);
        //warped so 2
        assertEq(twTAP.lastProcessedWeek(), 2);
        twTAP.advanceWeek(30);
        //still 2 as not warped
        assertEq(twTAP.lastProcessedWeek(), 2);
        vm.stopPrank();
    }

    function test_exit_position_before_expirity() public {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);

        aTapOFT.approve(address(twTAP), type(uint256).max);
        twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

        uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
        assertEq(balanceTwTAP, 100 ether);

        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));

        vm.warp(block.timestamp + 6 days);

        vm.expectRevert(LockNotExpired.selector);
        twTAP.exitPosition(1, address(owner));

        vm.stopPrank();
    }

    function test_exit_position() public {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);

        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);

        aTapOFT.approve(address(twTAP), type(uint256).max);

        twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

        uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
        assertEq(balanceTwTAP, 100 ether);

        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));

        vm.warp(block.timestamp + 1 weeks + 20 seconds);

        uint256 balanceOwnerBefore = aTapOFT.balanceOf(address(owner));
        assertEq(balanceOwnerBefore, 3_686_495 ether);

        vm.warp(block.timestamp + 1 weeks + 20 seconds);

        uint256 tapAmount_ = twTAP.exitPosition(1, address(owner));
        uint256 balanceownerAfter = aTapOFT.balanceOf(address(owner));
        assertEq(balanceownerAfter, 3_686_495 ether + tapAmount_);

        vm.stopPrank();
    }
}
