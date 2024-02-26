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
    ITapOFTv2,
    LockTwTapPositionMsg,
    UnlockTwTapPositionMsg,
    LZSendParam,
    ERC20PermitStruct,
    ERC721PermitStruct,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    ClaimTwTapRewardsMsg,
    RemoteTransferMsg
} from "@contracts/tokens/TapOFTv2/ITapOFTv2.sol";
import {
    TapOFTv2Helper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "@contracts/tokens/TapOFTv2/extensions/TapOFTv2Helper.sol";
import {TapOFTMsgCoder} from "@contracts/tokens/TapOFTv2/TapOFTMsgCoder.sol";
import {TwTAP, Participation} from "@contracts/governance/twTAP.sol";
import {TapOFTReceiver} from "@contracts/tokens/TapOFTv2/TapOFTReceiver.sol";
import {TapOFTSender} from "@contracts/tokens/TapOFTv2/TapOFTSender.sol";

// Tapioca Tests

import {TapTestHelper} from "../helpers/TapTestHelper.t.sol";
import {ERC721Mock} from "../Mocks/ERC721Mock.sol";
import {TapOFTV2Mock} from "../Mocks/TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";
import {IOracle} from "tapioca-periph/contracts/interfaces/IOracle.sol";

import {MockToken} from "gitsub_tapioca-sdk/src/contracts/mocks/MockToken.sol";

// Tapioca contracts
import {AOTAP} from "../../contracts/option-airdrop/AOTAP.sol";
import {OTAP} from "../../contracts/options/oTAP.sol";

import {YieldBox} from "gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/YieldBox.sol";
import {IYieldBox} from "tapioca-sdk/dist/contracts/YieldBox/contracts/interfaces/IYieldBox.sol";

import {IStrategy} from "gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/interfaces/IStrategy.sol";

import {TokenType} from "gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/enums/YieldBoxTokenType.sol";

// Import contract to test
import {AirdropBroker} from "../../contracts/option-airdrop/AirdropBroker.sol";
import {TapiocaOptionBroker} from "../../contracts/options/TapiocaOptionBroker.sol";
import {TapiocaOptionLiquidityProvision} from "../../contracts/options/TapiocaOptionLiquidityProvision.sol";

import {WrappedNativeMock} from "../Mocks/WrappedNativeMock.sol";
import {IWrappedNative} from "gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/interfaces/IWrappedNative.sol";

import {YieldBoxURIBuilder} from "gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/YieldBoxURIBuilder.sol";
import {Errors} from "../helpers/errors.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract TapiocaOptionLiquidityProvisionTest is TapTestHelper, Errors {
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
    MockToken public singularity; //instance of singularity (erc20)
    ERC721Mock public erc721Mock; //instance of ERC721Mock
    AOTAP public aotap; //instance of AOTAP
    OTAP public otap;
    TapiocaOptionBroker public tapiocaOptionBroker; //instance of TapiocaOptionBroker
    TapiocaOptionLiquidityProvision public tapiocaOptionLiquidityProvision; //instance of TapiocaOptionLiquidityProvision
    YieldBox public yieldBox; //instance of YieldBox
    YieldBoxURIBuilder public yieldBoxURIBuilder;
    WrappedNativeMock public wrappedNativeMock; //instance of wrappedNativeMock

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

    struct SingularityPool {
        uint256 sglAssetID; // Singularity market YieldBox asset ID
        uint256 totalDeposited; // total amount of YieldBox shares deposited, used for pool share calculation
        uint256 poolWeight; // Pool weight to calculate emission
        bool rescue; // If true, the pool will be used to rescue funds in case of emergency
    }

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
                        address(new TapOFTSender(address(endpoints[aEid]), address(this))),
                        address(new TapOFTReceiver(address(endpoints[aEid]), address(this)))
                    )
                )
            )
        );
        vm.label(address(aTapOFT), "aTapOFT"); //label address for test traces

        erc721Mock = new ERC721Mock("MockERC721", "Mock"); //deploy ERC721Mock
        vm.label(address(erc721Mock), "erc721Mock"); //label address for test traces
        tapOFTv2Helper = new TapOFTv2Helper();
        tapOracleMock = new TapOracleMock();

        yieldBoxURIBuilder = new YieldBoxURIBuilder();
        wrappedNativeMock = new WrappedNativeMock();
        yieldBox = new YieldBox(IWrappedNative(wrappedNativeMock), yieldBoxURIBuilder);
        otap = new OTAP();
        aotap = new AOTAP(address(this)); //deploy AOTAP and set address to owner

        tapiocaOptionLiquidityProvision = new TapiocaOptionLiquidityProvision(address(yieldBox), 7 days, address(owner));
        tapiocaOptionBroker = new TapiocaOptionBroker(
            address(tapiocaOptionLiquidityProvision),
            payable(address(otap)),
            payable(address(aTapOFT)),
            address(tokenBeneficiary),
            7 days,
            address(owner)
        );

        airdropBroker = new AirdropBroker(
            address(aotap), payable(address(aTapOFT)), address(erc721Mock), tokenBeneficiary, address(owner)
        );

        vm.startPrank(owner);
        mockToken = new MockToken("MockERC20", "Mock"); //deploy MockToken
        vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        mockToken.transfer(address(this), 1_000_001 * 10 ** 18); //transfer some tokens to address(this)
        mockToken.transfer(address(airdropBroker), 333333 * 10 ** 18);
        bytes memory _data = abi.encode(uint256(1));

        singularity = new MockToken("Singularity", "SGL"); //deploy singularity

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

    function test_constructor() public {
        IYieldBox _yieldBox = tapiocaOptionLiquidityProvision.yieldBox();
        assertEq(address(_yieldBox), address(yieldBox));
        uint256 _duration = tapiocaOptionLiquidityProvision.EPOCH_DURATION();
        assertEq(_duration, 7 days);
        address _owner = tapiocaOptionLiquidityProvision.owner();
        assertEq(_owner, address(owner));
    }

    function test_new_epoch_with_singularities() public {
        vm.startPrank(owner);
        vm.warp(block.timestamp + 7 days + 1 seconds);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularitesAfter = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularitesAfter.length, 1);
        assertEq(singularitesAfter[0], 1);
        vm.stopPrank();
    }

    function test_register_singularity_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);
        vm.stopPrank();
    }

    function test_register_singularity_id_not_valid() public {
        vm.startPrank(owner);
        vm.expectRevert(AssetIdNotValid.selector);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 0, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);
        vm.stopPrank();
    }

    function test_register_singularity_duplicated() public {
        vm.startPrank(owner);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        vm.expectRevert(DuplicateAssetId.selector);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularitesAfter = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularitesAfter.length, 1);
        assertEq(singularitesAfter[0], 1);
        vm.stopPrank();
    }

    function test_register_singularity_different_id() public {
        vm.startPrank(owner);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        vm.expectRevert(AlreadyRegistered.selector);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 2, 1);
        uint256[] memory singularitesAfter = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularitesAfter.length, 1);
        assertEq(singularitesAfter[0], 1);
        vm.stopPrank();
    }

    function test_register_singularity() public {
        vm.startPrank(owner);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        assertEq(singularites[0], 1);
        vm.stopPrank();
    }

    function test_unregister_singularity_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionLiquidityProvision.unregisterSingularity(singularity);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);
        vm.stopPrank();
    }

    function test_unregister_singularity_not_registered() public {
        vm.startPrank(owner);
        vm.expectRevert(NotRegistered.selector);
        tapiocaOptionLiquidityProvision.unregisterSingularity(singularity);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);
        vm.stopPrank();
    }

    function test_unregister_singularity_not_rescue() public {
        vm.startPrank(owner);
        //register
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        assertEq(singularites[0], 1);
        //unregister
        vm.expectRevert(NotInRescueMode.selector);
        tapiocaOptionLiquidityProvision.unregisterSingularity(singularity);
        uint256[] memory singularitesAfter = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularitesAfter.length, 1);
        assertEq(singularitesAfter[0], 1);
        vm.stopPrank();
    }

    function test_unregister_singularity() public {
        vm.startPrank(owner);
        //register
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        assertEq(singularites[0], 1);
        //activate
        tapiocaOptionLiquidityProvision.activateSGLPoolRescue(singularity);
        //unregister
        tapiocaOptionLiquidityProvision.unregisterSingularity(singularity);
        uint256[] memory singularitesAfter = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularitesAfter.length, 0);
        vm.stopPrank();
    }

    function test_activate_sgl_pool_rescue_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionLiquidityProvision.activateSGLPoolRescue(singularity);
        vm.stopPrank();
    }

    function test_activate_sgl_pool_rescue_not_registered() public {
        vm.startPrank(owner);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);
        //activate
        vm.expectRevert(NotRegistered.selector);
        tapiocaOptionLiquidityProvision.activateSGLPoolRescue(singularity);
        vm.stopPrank();
    }

    function test_activate_sgl_pool_rescue() public {
        vm.startPrank(owner);
        //register
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        assertEq(singularites[0], 1);
        //activate
        tapiocaOptionLiquidityProvision.activateSGLPoolRescue(singularity);
        vm.stopPrank();
    }

    function test_activate_sgl_pool_rescue_already_active() public {
        vm.startPrank(owner);
        //register
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        assertEq(singularites[0], 1);
        //activate
        tapiocaOptionLiquidityProvision.activateSGLPoolRescue(singularity);
        //activate again
        vm.expectRevert(AlreadyActive.selector);
        tapiocaOptionLiquidityProvision.activateSGLPoolRescue(singularity);
        vm.stopPrank();
    }

    function test_set_sgl_pool_weight__not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionLiquidityProvision.setSGLPoolWEight(singularity, 100);
        vm.stopPrank();
    }

    function test_set_sgl_pool_weight_not_registered() public {
        vm.startPrank(owner);

        vm.expectRevert(NotRegistered.selector);
        tapiocaOptionLiquidityProvision.setSGLPoolWEight(singularity, 100);
        vm.stopPrank();
    }

    function test_set_sgl_pool_weight() public {
        vm.startPrank(owner);

        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        assertEq(singularites[0], 1);
        vm.expectEmit(address(tapiocaOptionLiquidityProvision));
        emit TapiocaOptionLiquidityProvision.SetSGLPoolWeight(address(singularity), 100);
        tapiocaOptionLiquidityProvision.setSGLPoolWEight(singularity, 100);
        vm.stopPrank();
    }

    function test_lock_short_duration() public {
        vm.startPrank(owner);
        vm.expectRevert(DurationTooShort.selector);
        tapiocaOptionLiquidityProvision.lock(address(owner), singularity, 3 days, 1);
        vm.stopPrank();
    }

    function test_lock_not_valid_shares() public {
        vm.startPrank(owner);
        vm.expectRevert(SharesNotValid.selector);
        tapiocaOptionLiquidityProvision.lock(address(owner), singularity, 8 days, 0);
        vm.stopPrank();
    }

    function test_lock_in_rescue() public {
        vm.startPrank(owner);
        //register
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 1);
        assertEq(singularites[0], 1);
        //activate
        tapiocaOptionLiquidityProvision.activateSGLPoolRescue(singularity);
        vm.expectRevert(SingularityInRescueMode.selector);
        tapiocaOptionLiquidityProvision.lock(address(owner), singularity, 8 days, 1);
        vm.stopPrank();
    }

    function test_lock_not_active() public {
        vm.startPrank(owner);
        //register
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);

        vm.expectRevert(SingularityNotActive.selector);
        tapiocaOptionLiquidityProvision.lock(address(owner), singularity, 8 days, 1);
        vm.stopPrank();
    }

    function test_unlock_expired() public {
        vm.startPrank(owner);
        vm.expectRevert(PositionExpired.selector);
        tapiocaOptionLiquidityProvision.unlock(1, singularity, address(owner));
        vm.stopPrank();
    }
}
