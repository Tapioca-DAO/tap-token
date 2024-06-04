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
} from "tap-token/tokens/ITapToken.sol";
import {
    TapTokenHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "tap-token/tokens/extensions/TapTokenHelper.sol";
import {TapTokenCodec} from "tap-token/tokens/TapTokenCodec.sol";
import {TwTAP, Participation} from "tap-token/governance/twTAP.sol";
import {TapTokenReceiver} from "tap-token/tokens/TapTokenReceiver.sol";
import {TapTokenSender} from "tap-token/tokens/TapTokenSender.sol";
import {Pearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {IPearlmit} from "tapioca-periph/interfaces/periph/IPearlmit.sol";
import {ICluster, Cluster} from  "tapioca-periph/Cluster/Cluster.sol";

// Tapioca Tests
import {TapTestHelper} from "../helpers/TapTestHelper.t.sol";
import {ERC721Mock} from "../Mocks/ERC721Mock.sol";
import {TapTokenMock as TapOFTV2Mock} from "../Mocks/TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";

import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

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

    TapTokenHelper public tapTokenHelper; //instance of TapTokenHelper
    TapOFTV2Mock public aTapOFT; //instance of TapOFTV2Mock
    TapOFTV2Mock public bTapOFT; //instance of TapOFTV2Mock NOTE unused to the moment
    AirdropBroker public airdropBroker; //instance of AirdropBroker
    TapOracleMock public tapOracleMock; //instance of TapOracleMock
    ERC20Mock public mockToken; //instance of ERC20Mock (erc20)
    ERC721Mock public erc721Mock; //instance of ERC721Mock
    Pearlmit public pearlmit; //instance of Pearlmit
    Cluster public cluster; // instance of Cluster
    AOTAP public aotap; //instance of AOTAP

    TwTAP public twTAP; //instance of TwTAP

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    uint32 internal lzChainId = 1;
    address public owner = vm.addr(userAPKey);
    address public tokenBeneficiary = vm.addr(userBPKey);

    uint256 public constant EPOCH_DURATION = 7 days;

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
    address public __extExec = address(0x36);
    uint256 public __governanceEid = aEid; //aEid, initially bEid
    address public __owner = address(this);
    

    function setUp() public override {
        vm.deal(owner, 1000 ether); //give owner some ether
        vm.deal(tokenBeneficiary, 1000 ether); //give tokenBeneficiary some ether
        vm.label(owner, "owner"); //label address for test traces
        vm.label(tokenBeneficiary, "tokenBeneficiary"); //label address for test traces

        setUpEndpoints(3, LibraryType.UltraLightNode); //TODO: check if this is necessary

        pearlmit = new Pearlmit("Pearlmit", "v1", owner, type(uint256).max); // @audit setting nativeValueToCheckPauseState in Pearlmit to max to avoid potentially setting pause state unintentionally
        cluster = new Cluster(lzChainId, owner); // @audit setting lzChainId arg here to 1, unsure if this is correct

        aTapOFT = TapOFTV2Mock(
            payable(
                _deployOApp(
                    type(TapOFTV2Mock).creationCode,
                    abi.encode(
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
                        // @audit the two lines below have been updated to handle their new interfaces, with _extExec added as this address
                        address(new TapTokenSender("tap token sender", "tapSEND", address(endpoints[aEid]), address(this), address(this))),
                        address(new TapTokenReceiver("tap token receiver", "tapRECEIVE", address(endpoints[aEid]), address(this), address(this))),
                        __extExec,
                        IPearlmit(address(pearlmit)),
                        ICluster(address(cluster))
                    )
                )
            )
        );
        vm.label(address(aTapOFT), "aTapOFT"); //label address for test traces

        // erc721Mock = new ERC721Mock("MockERC721", "Mock"); //deploy ERC721Mock
        // vm.label(address(erc721Mock), "erc721Mock"); //label address for test traces
        // tapTokenHelper = new TapTokenHelper();
        // tapOracleMock = new TapOracleMock();
        // aotap = new AOTAP(IPearlmit(address(pearlmit)), address(this)); //deploy AOTAP and set address to owner

        // airdropBroker = new AirdropBroker(
        //     address(aotap), payable(address(aTapOFT)), tokenBeneficiary, IPearlmit(address(pearlmit)), address(owner)
        // );

        // vm.startPrank(owner);
        // mockToken = new ERC20Mock("MockERC20", "Mock"); //deploy ERC20Mock
        // vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        // mockToken.transfer(address(this), 1_000_001 * 10 ** 18); //transfer some tokens to address(this)
        // mockToken.transfer(address(airdropBroker), 333333 * 10 ** 18);
        // bytes memory _data = abi.encode(uint256(1));

        // erc721Mock.mint(address(owner), 1); //mint NFT id 1 to owner
        // erc721Mock.mint(address(tokenBeneficiary), 2); //mint NFT id 2 to beneficiary
        // airdropBroker.setTapOracle(tapOracleMock, _data);
        // vm.stopPrank();

        // twTAP = new TwTAP(payable(address(aTapOFT)), IPearlmit(address(pearlmit)), address(owner));

        // // config and wire the ofts
        // address[] memory ofts = new address[](1);
        // ofts[0] = address(aTapOFT);
        // this.wireOApps(ofts);

        // super.setUp();
    }

    function test_constructor() public {
        //ok
        // assertEq(twTAP.owner(), address(owner));
        // // assertEq(twTAP.tapOFT(), aTapOFT);
        // assertEq(twTAP.creation(), block.timestamp);
        // assertEq(twTAP.maxRewardTokens(), 1000);
    }

    // /// @notice tests that the participation duration must be > 7 days
    // function test_participation_1_day() public {
    //     //ok
    //     vm.startPrank(owner);
    //     vm.expectRevert(LockNotAWeek.selector);
    //     twTAP.participate(address(owner), 100 ether, 86400);
    //     //make sure no NFT has been minted
    //     vm.expectRevert(bytes("ERC721: invalid token ID"));
    //     address _owner = twTAP.ownerOf(1);
    //     vm.stopPrank();
    // }

    // /// @notice tests that lock duration can't be greater than 4x the current magnitude
    // function test_participate_with_magnitude() public {
    //     //ok
    //     vm.startPrank(__earlySupporters);
    //     //transfer tokens to the owner contract
    //     uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
    //     assertEq(balance, 3_686_595 ether);
    //     aTapOFT.transfer(address(owner), balance);
    //     vm.stopPrank();

    //     vm.startPrank(owner);
    //     aTapOFT.approve(address(twTAP), type(uint256).max);
    //     vm.expectRevert(NotValid.selector);
    //     twTAP.participate(address(owner), 100 ether, 1000 weeks);
    //     //make sure no NFT has been minted
    //     vm.expectRevert(bytes("ERC721: invalid token ID"));
    //     address _owner = twTAP.ownerOf(1);
    //     vm.stopPrank();
    // }

    // /// @notice tests a valid participation
    // function test_participate() public {
    //     //ok
    //     vm.startPrank(__earlySupporters);
    //     //transfer tokens to the owner contract
    //     uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
    //     assertEq(balance, 3_686_595 ether);
    //     aTapOFT.transfer(address(owner), balance);
    //     vm.stopPrank();

    //     vm.startPrank(owner);
    //     aTapOFT.approve(address(twTAP), type(uint256).max);
    //     twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));
    //     address _owner = twTAP.ownerOf(1);
    //     assertEq(_owner, address(owner));
    //     vm.stopPrank();
    // }

    // /// @notice tests that can't make claim when not participating and therefore NFT hasn't been minted
    // function test_claim_not_approved() public {
    //     //ok
    //     vm.startPrank(owner);
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
    //     assertEq(length, 2);

    //     bytes memory data = abi.encode(tokens[1]);
    //     bytes memory data2 = abi.encode(mockToken);
    //     assertEq(data, data2);

    //     uint256 balanceBefore = IERC20(mockToken).balanceOf(address(owner));
    //     vm.expectRevert(bytes("ERC721: invalid token ID"));
    //     twTAP.claimRewards(1);

    //     uint256 balanceAfter = IERC20(mockToken).balanceOf(address(owner));
    //     assertEq(balanceBefore, balanceAfter);

    //     vm.stopPrank();
    // }

    // /// @notice tests that if a reward token is added and a user participates, they receive the reward token on calling claimRewards
    // // @audit this doesn't actually accumulate any rewards because no time passes and there's no call to distributeReward
    // function test_claim_rewards() public {
    //     //ok
    //     vm.startPrank(__earlySupporters);
    //     //transfer tokens to the owner contract
    //     uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
    //     assertEq(balance, 3_686_595 ether);
    //     aTapOFT.transfer(address(owner), balance);
    //     vm.stopPrank();

    //     vm.startPrank(owner);
    //     aTapOFT.approve(address(twTAP), type(uint256).max);
    //     twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

    //     address _owner = twTAP.ownerOf(1);
    //     assertEq(_owner, address(owner));

    //     //add reward token
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
    //     assertEq(length, 2);

    //     bytes memory data = abi.encode(tokens[1]);
    //     bytes memory data2 = abi.encode(mockToken);
    //     assertEq(data, data2);

    //     uint256 balanceBefore = IERC20(mockToken).balanceOf(address(owner));
    //     uint256[] memory amounts_ = twTAP.claimRewards(1);
    //     uint256 balanceAfter = IERC20(mockToken).balanceOf(address(owner));
    //     assertEq(balanceAfter, balanceBefore + amounts_[1]);

    //     vm.stopPrank();
    // }

    // /// @notice tests that callers that aren't the owner can't call setMaxRewardTokensLength
    // function test_set_max_tokens_length_not_owner() public {
    //     //ok
    //     vm.startPrank(__earlySupporters);
    //     uint256 maxRewardTokensBefore = twTAP.maxRewardTokens();
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     twTAP.setMaxRewardTokensLength(30);
    //     uint256 maxRewardTokensAfter = twTAP.maxRewardTokens();
    //     assertEq(maxRewardTokensBefore, maxRewardTokensAfter);
    //     vm.stopPrank();
    // }

    // /// @notice tests that max rewards tokens length gets properly set when called by owner
    // function test_set_max_tokens_length() public {
    //     //ok
    //     vm.startPrank(owner);
    //     uint256 maxRewardTokens = twTAP.maxRewardTokens();
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     // vm.expectEmit(address(twTAP));
    //     // emit twTAP.LogMaxRewardsLength(maxRewardTokens, 30, length);
    //     twTAP.setMaxRewardTokensLength(30);
    //     assertEq(twTAP.maxRewardTokens(), 30);

    //     vm.stopPrank();
    // }

    // /// @notice the same reward token can't be added more than once
    // function test_register_twice_reward_token() public {
    //     //ok
    //     vm.startPrank(owner);
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     vm.expectRevert(Registered.selector);
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     //length has to be 2 because we push on the constructor
    //     assertEq(length, 2);
    //     vm.stopPrank();
    // }

    // /// @notice can't add more reward tokens than the maxRewardTokens
    // function test_add_max_reward_token() public {
    //     //ok
    //     vm.startPrank(owner);
    //     address tokenB = address(uint160(0x08));
    //     twTAP.setMaxRewardTokensLength(2);
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     vm.expectRevert(TokenLimitReached.selector);
    //     twTAP.addRewardToken(IERC20(tokenB));
    //     vm.stopPrank();
    // }

    // /// @notice only owner can add reward tokens
    // function test_add_reward_token_not_owner() public {
    //     //ok
    //     vm.startPrank(__earlySupporters);
    //     vm.expectRevert(bytes("Ownable: caller is not the owner"));
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     //check token has indeed not been added
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     assertEq(length, 1);
    //     vm.stopPrank();
    // }

    // /// @notice owner can add reward token
    // function test_add_reward_token() public {
    //     //ok
    //     vm.startPrank(owner);
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
    //     assertEq(length, 2);
    //     //assertEq does not work with addresses or types, so we have to cast it to bytes
    //     bytes memory data = abi.encode(tokens[1]);
    //     bytes memory data2 = abi.encode(mockToken);
    //     assertEq(data, data2);
    //     vm.stopPrank();
    // }

    // /// @notice rewards can only be distributed once votes have been accumulated for previous weeks by calling advanceWeek
    // function test_distribute_rewards_on_different_weeks() public {
    //     //ok
    //     vm.startPrank(owner);

    //     twTAP.addRewardToken(IERC20(mockToken));
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
    //     assertEq(length, 2);

    //     bytes memory data = abi.encode(tokens[1]);
    //     bytes memory data2 = abi.encode(mockToken);
    //     assertEq(data, data2);

    //     vm.warp(block.timestamp + 1 weeks + 1 seconds);

    //     IERC20(mockToken).approve(address(twTAP), type(uint256).max);

    //     uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(address(owner));
    //     // vm.expectRevert(bytes("0x12"));ß
    //     vm.expectRevert(AdvanceWeekFirst.selector);
    //     twTAP.distributeReward(1, 1);
    //     uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
    //     assertEq(balanceOwnerAfter, balanceOwnerBefore);

    //     vm.stopPrank();
    // }

    // /// @notice trying to distribute 0 reward amount fails
    // function test_distribute_rewards_no_amount() public {
    //     //ok
    //     vm.startPrank(owner);

    //     //add rewards tokens
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
    //     assertEq(length, 2);

    //     bytes memory data = abi.encode(tokens[1]);
    //     bytes memory data2 = abi.encode(mockToken);
    //     assertEq(data, data2);

    //     //participate
    //     vm.startPrank(__earlySupporters);
    //     //transfer tokens to the owner contract
    //     uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
    //     assertEq(balance, 3_686_595 ether);

    //     aTapOFT.transfer(address(owner), balance);
    //     vm.stopPrank();

    //     vm.startPrank(owner);

    //     aTapOFT.approve(address(twTAP), type(uint256).max);

    //     twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

    //     uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
    //     assertEq(balanceTwTAP, 100 ether);

    //     address _owner = twTAP.ownerOf(1);
    //     assertEq(_owner, address(owner));

    //     //advance a week
    //     vm.warp(block.timestamp + 1 weeks + 1 seconds);
    //     twTAP.advanceWeek(100);
    //     assertEq(twTAP.lastProcessedWeek(), 1);

    //     //distribute rewards
    //     IERC20(mockToken).approve(address(twTAP), type(uint256).max);

    //     uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(address(owner));
    //     vm.expectRevert(NotValid.selector);
    //     twTAP.distributeReward(1, 0);
    //     uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
    //     assertEq(balanceOwnerAfter, balanceOwnerBefore);

    //     vm.stopPrank();
    // }

    // /// @notice user receives rewards after they accumulate over a week
    // function test_distribute_rewards() public {
    //     //ok
    //     vm.startPrank(owner);

    //     //add rewards tokens
    //     twTAP.addRewardToken(IERC20(mockToken));
    //     IERC20[] memory tokens = twTAP.getRewardTokens();
    //     uint256 length = tokens.length;
    //     //length has to be 2 because we push on the constructor:  rewardTokens.push(IERC20(address(0x0)));
    //     assertEq(length, 2);

    //     bytes memory data = abi.encode(tokens[1]);
    //     bytes memory data2 = abi.encode(mockToken);
    //     assertEq(data, data2);

    //     //participate
    //     vm.startPrank(__earlySupporters);
    //     //transfer tokens to the owner contract
    //     uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
    //     assertEq(balance, 3_686_595 ether);

    //     aTapOFT.transfer(address(owner), balance);
    //     vm.stopPrank();

    //     vm.startPrank(owner);

    //     aTapOFT.approve(address(twTAP), type(uint256).max);

    //     twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

    //     uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
    //     assertEq(balanceTwTAP, 100 ether);

    //     address _owner = twTAP.ownerOf(1);
    //     assertEq(_owner, address(owner));

    //     //advance a week
    //     vm.warp(block.timestamp + 1 weeks + 1 seconds);
    //     twTAP.advanceWeek(100);
    //     assertEq(twTAP.lastProcessedWeek(), 1);

    //     //distribute rewards
    //     IERC20(mockToken).approve(address(twTAP), type(uint256).max);
    //     //NOTE if this is called before nothing is done, there will be a panic error when
    //     //dividing (_amount * DIST_PRECISION) / uint256(totals.netActiveVotes), as the denominator will be 0

    //     //NOTE so cool thing is that netActiveVotes is incremented in the new week when you participate therefore if you participate and try and claim before a week has passed, you will get a panic revert
    //     //weekTotals[w0 + 1].netActiveVotes += int256(votes);

    //     uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(address(owner));
    //     twTAP.distributeReward(1, 1);
    //     uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
    //     assertEq(balanceOwnerAfter, balanceOwnerBefore - 1);

    //     vm.stopPrank();
    // }

    // /// @notice week advances up to actual current week
    // function test_advance_week() public {
    //     //ok
    //     vm.startPrank(owner);
    //     uint256 currentWeek = twTAP.currentWeek(); //0
    //     //warp 7 days + 1 second to satisfy the next epoch
    //     vm.warp(block.timestamp + 1 weeks + 1 seconds);
    //     twTAP.advanceWeek(100);
    //     assertEq(twTAP.lastProcessedWeek(), 1); //0
    //     vm.stopPrank();
    // }

    // /// @notice week can't advance past current on multiple advances 
    // function test_advance_week_multiple() public {
    //     //ok
    //     vm.startPrank(owner);
    //     uint256 currentWeek = twTAP.currentWeek(); //0
    //     //warp 7 days + 1 second to satisfy the next epoch
    //     vm.warp(block.timestamp + 1 weeks + 1 seconds);
    //     twTAP.advanceWeek(100);
    //     //warped so 1
    //     assertEq(twTAP.lastProcessedWeek(), 1);
    //     vm.warp(block.timestamp + 1 weeks);
    //     twTAP.advanceWeek(30);
    //     //warped so 2
    //     assertEq(twTAP.lastProcessedWeek(), 2);
    //     twTAP.advanceWeek(30);
    //     //still 2 as not warped
    //     assertEq(twTAP.lastProcessedWeek(), 2);
    //     vm.stopPrank();
    // }

    // /// @notice user can't exit position before lock expires
    // function test_exit_position_before_expirity() public {
    //     //ok
    //     vm.startPrank(__earlySupporters);
    //     //transfer tokens to the owner contract
    //     uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
    //     assertEq(balance, 3_686_595 ether);
    //     aTapOFT.transfer(address(owner), balance);
    //     vm.stopPrank();

    //     vm.startPrank(owner);

    //     aTapOFT.approve(address(twTAP), type(uint256).max);
    //     twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

    //     uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
    //     assertEq(balanceTwTAP, 100 ether);

    //     address _owner = twTAP.ownerOf(1);
    //     assertEq(_owner, address(owner));

    //     vm.warp(block.timestamp + 6 days);

    //     vm.expectRevert(LockNotExpired.selector);
    //     twTAP.exitPosition(1);

    //     vm.stopPrank();
    // }

    // /// @notice user receives their full balance back after exiting
    // function test_exit_position() public {
    //     //ok
    //     vm.startPrank(__earlySupporters);
    //     //transfer tokens to the owner contract
    //     uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
    //     assertEq(balance, 3_686_595 ether);

    //     aTapOFT.transfer(address(owner), balance);
    //     vm.stopPrank();

    //     vm.startPrank(owner);

    //     aTapOFT.approve(address(twTAP), type(uint256).max);

    //     twTAP.participate(address(owner), 100 ether, ((86400 + 1) * 7));

    //     uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
    //     assertEq(balanceTwTAP, 100 ether);

    //     address _owner = twTAP.ownerOf(1);
    //     assertEq(_owner, address(owner));

    //     vm.warp(block.timestamp + 1 weeks + 20 seconds);

    //     uint256 balanceOwnerBefore = aTapOFT.balanceOf(address(owner));
    //     assertEq(balanceOwnerBefore, 3_686_495 ether);

    //     vm.warp(block.timestamp + 1 weeks + 20 seconds);

    //     uint256 tapAmount_ = twTAP.exitPosition(1);
    //     uint256 balanceownerAfter = aTapOFT.balanceOf(address(owner));
    //     assertEq(balanceownerAfter, 3_686_495 ether + tapAmount_);

    //     vm.stopPrank();
    // }
}
