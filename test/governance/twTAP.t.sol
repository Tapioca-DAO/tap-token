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
import {TWAML} from "tap-token/options/twAML.sol";

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

        pearlmit = new Pearlmit("Pearlmit", "v1", owner, type(uint256).max); // NOTE: setting nativeValueToCheckPauseState in Pearlmit to max to avoid potentially setting pause state unintentionally
        cluster = new Cluster(lzChainId, owner); // NOTE: setting lzChainId arg here to 1, unsure if this is correct

        // NOTE: this replaces previous deploy method via _deployOApp that cause stack too deep error
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
                address(__extExec),
                IPearlmit(address(pearlmit)),
                ICluster(address(cluster))
            )
        );
        vm.label(address(aTapOFT), "aTapOFT"); //label address for test traces

        erc721Mock = new ERC721Mock("MockERC721", "Mock"); //deploy ERC721Mock
        vm.label(address(erc721Mock), "erc721Mock"); //label address for test traces
        tapTokenHelper = new TapTokenHelper();
        tapOracleMock = new TapOracleMock();
        aotap = new AOTAP(IPearlmit(address(pearlmit)), address(this)); //deploy AOTAP and set address to owner

        airdropBroker = new AirdropBroker(
            address(aotap), payable(address(aTapOFT)), tokenBeneficiary, IPearlmit(address(pearlmit)), address(owner)
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
        vm.stopPrank();

        twTAP = new TwTAP(payable(address(aTapOFT)), IPearlmit(address(pearlmit)), address(owner));

        // config and wire the ofts
        address[] memory ofts = new address[](1);
        ofts[0] = address(aTapOFT);
        this.wireOApps(ofts);

        super.setUp();
    }

    function test_constructor() public {
        //ok
        // assertEq(twTAP.owner(), address(owner));
        // // assertEq(twTAP.tapOFT(), aTapOFT);
        // assertEq(twTAP.creation(), block.timestamp);
        // assertEq(twTAP.maxRewardTokens(), 1000);
    }

    /**
     Fuzz Tests
    */
    function testFuzz_participation(uint256 lockTime) public {
        test_participation_1_day(lockTime);
    }

    function testFuzz_participate_with_magnitude(uint256 amount, uint256 duration) public {
        amount = bound(amount, 100 ether, 3_686_595 ether);
        duration = bound(duration, 1000 weeks, 2000 weeks);
        vm.assume(duration % 7 days == 0);
        test_participate_with_magnitude(amount, duration);
    }

    function testFuzz_participate(uint256 amount, uint256 duration) public {
        // upper bound of duration is magnitude < pool.cumulative * 4
        uint256 durationUpperBound = _calculateDurationUpperBound();
        duration = bound(duration, 86400, durationUpperBound - 1 seconds);
        // using vm.assume throws here, so need to filter duration values that aren't the length of an epoch with the following if statement
        if(duration % 7 days != 0) {
            return;
        }

        amount = bound(amount, 100 ether, 3_686_595 ether);

        test_participate(amount, duration);
    }

    function testFuzz_claim_rewards(uint256 amount, uint256 duration) public { 
        // upper bound of duration is magnitude < pool.cumulative * 4
        uint256 durationUpperBound = _calculateDurationUpperBound();
        duration = bound(duration, 86400, durationUpperBound - 1 seconds);
        // using vm.assume throws here, so need to filter duration values that aren't the length of an epoch with the following if statement
        if(duration % 7 days != 0) {
            return;
        }

        amount = bound(amount, 100 ether, 3_686_595 ether);

        test_claim_rewards(amount, duration);
    }

    function testFuzz_distribute_rewards(uint256 amount, uint256 duration) public {
        // upper bound of duration is magnitude < pool.cumulative * 4
        uint256 durationUpperBound = _calculateDurationUpperBound();
        duration = bound(duration, 86400, durationUpperBound - 1 seconds);
        // using vm.assume throws here, so need to filter duration values that aren't the length of an epoch with the following if statement
        if(duration % 7 days != 0) {
            return;
        }

        amount = bound(amount, 100 ether, 3_686_595 ether);

        test_distribute_rewards(amount, duration);
    }

    function testFuzz_advance_week(uint256 warpTime) public { 
        warpTime = bound(warpTime, block.timestamp + 1 weeks + 1 seconds, block.timestamp + 100 weeks + 1 seconds);
        vm.assume(warpTime / 1 weeks < 100);
        test_advance_week(warpTime);
    }

    function testFuzz_exit_position(uint256 amount, uint256 duration, uint256 warpTime) public { 
        // upper bound of duration is magnitude < pool.cumulative * 4
        uint256 durationUpperBound = _calculateDurationUpperBound();
        duration = bound(duration, 86400, durationUpperBound - 1 seconds);
        // using vm.assume throws here, so need to filter duration values that aren't the length of an epoch with the following if statement
        if(duration % 7 days != 0) {
            return;
        }

        amount = bound(amount, 100 ether, 3_686_595 ether);

        // time to warp ahead before exiting position
        warpTime = bound(warpTime, block.timestamp + 1 weeks + 1 seconds, block.timestamp + 100 weeks + 1 seconds);
        vm.assume(warpTime / 1 weeks < 100);

        test_exit_position(amount, duration, warpTime);
    }

    /**
        Wrappers
    */

    function test_participation_wrapper() public {
        test_participation_1_day(86400);
    }

    function test_participate_with_magnitude_wrapper() public {
        test_participate_with_magnitude(100 ether, 1000 weeks);
    }

    function test_participate_wrapper() public {
        test_participate(100 ether,((86400) * 7));
    }

    function test_claim_rewards_wrapper() public {
        test_claim_rewards(100 ether, (86400) * 7);
    }

    function test_distribute_rewards_wrapper() public {
        test_distribute_rewards(100 ether, ((86400) * 7));
    }

    function test_advance_week_wrapper(uint256 warpTime) public { 
        test_advance_week(block.timestamp + 1 weeks + 1 seconds);
    }

    function test_exit_position_wrapper() public {
        test_exit_position(100 ether, ((86400) * 7), block.timestamp + 1 weeks + 20 seconds);
    }

    /**
        Unit Test Implementations
    */

    /// @notice tests that the participation duration must be > 7 days
    function test_participation_1_day(uint256 lockTime) internal {
        lockTime = bound(lockTime, 1, 86400);
        //ok
        vm.startPrank(owner);
        vm.expectRevert(LockNotAWeek.selector);
        twTAP.participate(address(owner), 100 ether, lockTime);
        //make sure no NFT has been minted
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        address _owner = twTAP.ownerOf(1);
        vm.stopPrank();
    }

    /// @notice tests that lock duration can't be greater than 4x the current magnitude
    function test_participate_with_magnitude(uint256 amount, uint256 duration) internal {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);
        // owner needs to use Pearlmit to approve twTAP for their TAP
        aTapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(aTapOFT), 0, address(twTAP), type(uint200).max, type(uint48).max); 
        
        vm.expectRevert(NotValid.selector);
        // twTAP.participate(address(owner), 100 ether, 1000 weeks);
        twTAP.participate(address(owner), amount, duration);

        //make sure no NFT has been minted
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        address _owner = twTAP.ownerOf(1);

        vm.stopPrank();
    }

    /// @notice tests a valid participation
    function test_participate(uint256 amount, uint256 duration) internal {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);
        aTapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(aTapOFT), 0, address(twTAP), type(uint200).max, type(uint48).max); 
        twTAP.participate(address(owner), amount, duration);
        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));
        vm.stopPrank();
    }

    /// @notice tests that can't make claim if not the owner or approved
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
        vm.expectRevert(abi.encodeWithSelector(TwTAP.NotApproved.selector, 1, owner));
        twTAP.claimRewards(1);

        uint256 balanceAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceBefore, balanceAfter);

        vm.stopPrank();
    }

    /// @notice tests that if a reward token is added and a user participates, they receive the reward token on calling claimRewards
    // NOTE: this doesn't actually accumulate any rewards because no time passes and there's no call to distributeReward
    function test_claim_rewards(uint256 amount, uint256 duration) internal {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);
        aTapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(aTapOFT), 0, address(twTAP), type(uint200).max, type(uint48).max); // NOTE: replaces previous approval implementation to approve through Pearlmit
        twTAP.participate(address(owner), amount, duration);

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
        uint256[] memory amounts_ = twTAP.claimRewards(1);
        uint256 balanceAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceAfter, balanceBefore + amounts_[1]);

        vm.stopPrank();
    }

    /// @notice tests that callers that aren't the owner can't call setMaxRewardTokensLength
    function test_set_max_tokens_length_not_owner() public {
        //ok
        vm.startPrank(__earlySupporters);
        uint256 maxRewardTokensBefore = twTAP.maxRewardTokens();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        twTAP.setMaxRewardTokensLength(30);
        uint256 maxRewardTokensAfter = twTAP.maxRewardTokens();
        assertEq(maxRewardTokensBefore, maxRewardTokensAfter);
        vm.stopPrank();
    }

    /// @notice tests that max rewards tokens length gets properly set when called by owner
    function test_set_max_tokens_length() public {
        //ok
        vm.startPrank(owner);
        uint256 maxRewardTokens = twTAP.maxRewardTokens();
        IERC20[] memory tokens = twTAP.getRewardTokens();
        uint256 length = tokens.length;
        // vm.expectEmit(address(twTAP));
        // emit twTAP.LogMaxRewardsLength(maxRewardTokens, 30, length);
        twTAP.setMaxRewardTokensLength(30);
        assertEq(twTAP.maxRewardTokens(), 30);

        vm.stopPrank();
    }

    /// @notice the same reward token can't be added more than once
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

    /// @notice can't add more reward tokens than the maxRewardTokens
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

    /// @notice only owner can add reward tokens
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

    /// @notice owner can add reward token
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

    /// @notice rewards can only be distributed once votes have been accumulated for previous weeks by calling advanceWeek
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

        uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(address(owner));
        // vm.expectRevert(bytes("0x12"));ß
        vm.expectRevert(AdvanceWeekFirst.selector);
        twTAP.distributeReward(1, 1);
        uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceOwnerAfter, balanceOwnerBefore);

        vm.stopPrank();
    }

    /// @notice trying to distribute 0 reward amount fails
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

        // NOTE: added this transfer of reward tokens to owner which was missing
        mockToken.transfer(owner, mockToken.balanceOf(address(this)) / 2);

        vm.startPrank(owner);

        aTapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(aTapOFT), 0, address(twTAP), type(uint200).max, type(uint48).max); 
        twTAP.participate(address(owner), 100 ether, ((86400) * 7));

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

        uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(address(owner));
        vm.expectRevert(NotValid.selector);
        twTAP.distributeReward(1, 0);
        uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceOwnerAfter, balanceOwnerBefore);

        vm.stopPrank();
    }

    /// @notice user receives rewards after they accumulate over a week
    function test_distribute_rewards(uint256 amount, uint256 duration) internal {
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
        vm.stopPrank();

        // NOTE: added this transfer of reward tokens to owner which was missing
        mockToken.transfer(owner, mockToken.balanceOf(address(this)) / 2);

        //participate
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);

        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);

        aTapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(aTapOFT), 0, address(twTAP), type(uint200).max, type(uint48).max); 
        
        twTAP.participate(address(owner), amount, duration);

        uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
        assertEq(balanceTwTAP, amount);

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

        uint256 balanceOwnerBefore = IERC20(mockToken).balanceOf(address(owner));
        twTAP.distributeReward(1, 1);
        uint256 balanceOwnerAfter = IERC20(mockToken).balanceOf(address(owner));
        assertEq(balanceOwnerAfter, balanceOwnerBefore - 1);

        vm.stopPrank();
    }

    /// @notice week advances up to actual current week
    function test_advance_week(uint256 warpTime) internal {
        //ok
        vm.startPrank(owner);
        uint256 currentWeek = twTAP.currentWeek(); //0
        vm.warp(warpTime);
        twTAP.advanceWeek(100);
        uint256 timeInWeeks = warpTime / 1 weeks;
        assertEq(twTAP.lastProcessedWeek(), timeInWeeks); 
        vm.stopPrank();
    }

    /// @notice week can't advance past current on multiple advances 
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

    /// @notice user can't exit position before lock expires
    function test_exit_position_before_expirity() public {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);
        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);

        aTapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(aTapOFT), 0, address(twTAP), type(uint200).max, type(uint48).max); 
        twTAP.participate(address(owner), 100 ether, ((86400) * 7));

        uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
        assertEq(balanceTwTAP, 100 ether);

        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));

        vm.warp(block.timestamp + 6 days);

        vm.expectRevert(LockNotExpired.selector);
        twTAP.exitPosition(1);

        vm.stopPrank();
    }

    /// @notice user receives their full balance back after exiting
    function test_exit_position(uint256 amount, uint256 duration, uint256 warpTime) internal {
        //ok
        vm.startPrank(__earlySupporters);
        //transfer tokens to the owner contract
        uint256 balance = aTapOFT.balanceOf(address(__earlySupporters));
        assertEq(balance, 3_686_595 ether);

        aTapOFT.transfer(address(owner), balance);
        vm.stopPrank();

        vm.startPrank(owner);

        aTapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(aTapOFT), 0, address(twTAP), type(uint200).max, type(uint48).max); 

        twTAP.participate(address(owner), amount, duration);

        uint256 balanceTwTAP = aTapOFT.balanceOf(address(twTAP));
        assertEq(balanceTwTAP, amount);

        address _owner = twTAP.ownerOf(1);
        assertEq(_owner, address(owner));

        vm.warp(warpTime);

        uint256 balanceOwnerBefore = aTapOFT.balanceOf(address(owner));
        assertEq(balanceOwnerBefore, 3_686_495 ether);

        vm.warp(warpTime);

        uint256 tapAmount_ = twTAP.exitPosition(1);
        uint256 balanceownerAfter = aTapOFT.balanceOf(address(owner));
        assertEq(balanceownerAfter, 3_686_495 ether + tapAmount_);

        vm.stopPrank();
    }

    /// @notice helper for clamping inputs for fuzz tests
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @notice calculates the duration upper bound given a pool's current cumulative value
    function _calculateDurationUpperBound() internal returns (uint256 durationUpperBound) {
        (,,, uint256 cumulative) = twTAP.twAML();
        uint256 maxMagnitude = cumulative * 4;
        durationUpperBound = _sqrt((maxMagnitude + cumulative) * (maxMagnitude + cumulative) - (cumulative * cumulative));
    }
}
