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
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {IPearlmit, Pearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {ICluster, Cluster} from  "tapioca-periph/Cluster/Cluster.sol";
import {TapTokenReceiver} from "tap-token/tokens/TapTokenReceiver.sol";
import {TwTAP, Participation} from "tap-token/governance/twTAP.sol";
import {TapTokenSender} from "tap-token/tokens/TapTokenSender.sol";
import {TapTokenCodec} from "tap-token/tokens/TapTokenCodec.sol";

// Tapioca Tests

import {TapTestHelper} from "../helpers/TapTestHelper.t.sol";
import {ERC721Mock} from "../Mocks/ERC721Mock.sol";
import {TapTokenMock as TapOFTV2Mock} from "../Mocks/TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";
import {ITapiocaOracle} from "tapioca-periph/interfaces/periph/ITapiocaOracle.sol";

import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

// Tapioca contracts
import {AOTAP} from "../../contracts/option-airdrop/AOTAP.sol";
import {OTAP} from "../../contracts/options/oTAP.sol";

import {YieldBox} from "tap-yieldbox/YieldBox.sol";
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";

import {IStrategy} from "tap-yieldbox/interfaces/IStrategy.sol";
import {TokenType} from "tap-yieldbox/enums/YieldBoxTokenType.sol";

// Import contract to test
import {AirdropBroker} from "../../contracts/option-airdrop/AirdropBroker.sol";
import {TapiocaOptionBroker, PaymentTokenOracle} from "../../contracts/options/TapiocaOptionBroker.sol";
import {TapiocaOptionLiquidityProvision} from "../../contracts/options/TapiocaOptionLiquidityProvision.sol";

import {WrappedNativeMock} from "../Mocks/WrappedNativeMock.sol";
import {IWrappedNative} from "tap-yieldbox/interfaces/IWrappedNative.sol";

import {YieldBoxURIBuilder} from "tap-yieldbox/YieldBoxURIBuilder.sol";
import {Errors} from "../helpers/errors.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract TapiocaOptionBrokerTest is TapTestHelper, Errors {
    using stdStorage for StdStorage;

    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    TapTestHelper public tapOFTv2Helper; //instance of TapTestHelper
    TapOFTV2Mock public aTapOFT; //instance of TapOFTV2Mock
    TapOFTV2Mock public bTapOFT; //instance of TapOFTV2Mock NOTE unused to the moment
    AirdropBroker public airdropBroker; //instance of AirdropBroker
    TapOracleMock public tapOracleMock; //instance of TapOracleMock
    ERC20Mock public mockToken; //instance of ERC20Mock (erc20)
    ERC20Mock public singularity; //instance of singularity (erc20)
    ERC721Mock public erc721Mock; //instance of ERC721Mock
    AOTAP public aotap; //instance of AOTAP
    OTAP public otap;
    TapiocaOptionBroker public tapiocaOptionBroker; //instance of TapiocaOptionBroker
    TapiocaOptionLiquidityProvision public tapiocaOptionLiquidityProvision; //instance of TapiocaOptionLiquidityProvision
    YieldBox public yieldBox; //instance of YieldBox
    YieldBoxURIBuilder public yieldBoxURIBuilder;
    WrappedNativeMock public wrappedNativeMock; //instance of wrappedNativeMock
    TapiocaOmnichainExtExec extExec;
    Pearlmit pearlmit;
    Cluster cluster; 

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public owner = vm.addr(userAPKey);
    address public tokenBeneficiary = vm.addr(userBPKey);
    uint256 public EPOCH_DURATION = 7 days;
    uint32 internal lzChainId = 1;

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

        extExec = new TapiocaOmnichainExtExec();
        pearlmit = new Pearlmit("Pearlmit", "1", owner, type(uint256).max); // @audit setting nativeValueToCheckPauseState in Pearlmit to max to avoid potentially setting pause state unintentionally
        cluster = new Cluster(lzChainId, owner); // @audit setting lzChainId arg here to 1, unsure if this is correct

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
        tapOFTv2Helper = new TapTestHelper();
        tapOracleMock = new TapOracleMock();

        yieldBoxURIBuilder = new YieldBoxURIBuilder();
        wrappedNativeMock = new WrappedNativeMock();
        yieldBox = new YieldBox(IWrappedNative(wrappedNativeMock), yieldBoxURIBuilder, pearlmit, owner);
        otap = new OTAP(address(this));
        aotap = new AOTAP(IPearlmit(address(pearlmit)), address(this)); //deploy AOTAP and set address to owner

        // NOTE: this currently sets tapiocaOptionBroker address in tapiocaOptionLiquidityProvision because it's not deployed yet but since these contracts are self-referencing 
        // and set these values as immutable there's no simple fix. Since the functions called on tapiocaOptionLiquidityProvision in these tests aren't dependent on what the tapiocaOptionBroker is set to this is the simplest workaround
        tapiocaOptionLiquidityProvision =
            new TapiocaOptionLiquidityProvision(address(yieldBox), 7 days, IPearlmit(address(pearlmit)), address(owner), address(tapiocaOptionBroker));

        airdropBroker = new AirdropBroker(
            address(aotap), address(erc721Mock), tokenBeneficiary, IPearlmit(address(pearlmit)), address(owner)
        );
        // NOTE: this was not deployed in previous setup
        tapiocaOptionBroker = new TapiocaOptionBroker(
            address(tapiocaOptionLiquidityProvision),
            address(otap),
            payable(address(aTapOFT)),
            tokenBeneficiary,
            EPOCH_DURATION,
            IPearlmit(address(pearlmit)),
            owner
        );


        vm.startPrank(owner);
        mockToken = new ERC20Mock("MockERC20", "Mock"); //deploy ERC20Mock
        vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        // mockToken.transfer(address(this), 1_000_001 * 10 ** 18); //transfer some tokens to address(this)
        mockToken.mint(address(this), 1_000_001 * 10 ** 18); //mint some tokens to address(this)
        mockToken.mint(address(airdropBroker), 333333 * 10 ** 18);
        bytes memory _data = abi.encode(uint256(1));

        singularity = new ERC20Mock("Singularity", "SGL"); //deploy singularity

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

    /// @notice returns the correct week for a given timestamp
    function test_timestamp() public {
        uint256 return_value = tapiocaOptionBroker.timestampToWeek(0);
        assertEq(return_value, 0, "timestamp from 0 fails");
        uint256 return_value2 = tapiocaOptionBroker.timestampToWeek(block.timestamp - 1 seconds);
        assertEq(return_value2, 0, "timestamp from previous time fails");
        uint256 return_value3 = tapiocaOptionBroker.timestampToWeek(block.timestamp + (7 days - 1 seconds));
        assertEq(return_value3, 0, "timestamp less than epoch fails");
        uint256 return_value4 = tapiocaOptionBroker.timestampToWeek(block.timestamp + 8 days);
        assertEq(return_value4, 1, "timestamp in future fails");
    }

    /// @notice only the owner can set the token beneficiary
    function test_set_payment_token_beneficiary_not_owner() public {
        vm.startPrank(__earlySupporters);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionBroker.setPaymentTokenBeneficiary(address(0x1));
        assertEq(tapiocaOptionBroker.paymentTokenBeneficiary(), address(tokenBeneficiary));
        vm.stopPrank();
    }

    /// @notice token beneficiary is correctly set
    function test_set_payment_token_beneficiary() public {
        vm.startPrank(owner);
        assertEq(tapiocaOptionBroker.paymentTokenBeneficiary(), address(tokenBeneficiary));
        tapiocaOptionBroker.setPaymentTokenBeneficiary(address(0x1));
        assertEq(tapiocaOptionBroker.paymentTokenBeneficiary(), address(0x1));
        vm.stopPrank();
    }

    /// @notice only owner can set the MIN_WEIGHT_FACTOR
    function test_set_min_weigth_factor_not_owner() public {
        vm.startPrank(__earlySupporters);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionBroker.setMinWeightFactor(2000);
        assertEq(tapiocaOptionBroker.MIN_WEIGHT_FACTOR(), 1000);
        vm.stopPrank();
    }

    /// @notice min weight factor is correctly set
    function test_set_min_weigth_factor() public {
        vm.startPrank(owner);
        assertEq(tapiocaOptionBroker.MIN_WEIGHT_FACTOR(), 1000);
        tapiocaOptionBroker.setMinWeightFactor(2000);
        assertEq(tapiocaOptionBroker.MIN_WEIGHT_FACTOR(), 2000);
        vm.stopPrank();
    }

    /// @notice can't claim broker if already set
    function test_claim_broker_twice() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        address _broker = otap.broker();
        assertEq(_broker, address(owner));
        vm.expectRevert(OnlyOnce.selector);
        otap.brokerClaim();
        vm.stopPrank();
    }

    /// @notice only the owner can set the payment token
    function test_payment_token_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        address user1 = address(0x01);
        bytes memory _data = abi.encode(uint256(3));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionBroker.setPaymentToken((mockToken), ITapiocaOracle(tapOracleMock), _data);

        vm.stopPrank();
    }

    /// @notice the payment token is correctly set
    function test_payment_token() public {
        //ok
        vm.startPrank(owner);
        bytes memory data = abi.encode(uint256(3));
        tapiocaOptionBroker.setPaymentToken((mockToken), ITapiocaOracle(tapOracleMock), data);
        // @audit fixed this to use values from paymentTokens mapping
        (ITapiocaOracle _tokenOracle, bytes memory _tokenOracledata) = tapiocaOptionBroker.paymentTokens(mockToken);
        // @audit added the below assertions because they were missing
        assertEq(address(_tokenOracle), address(tapOracleMock));
        assertEq(_tokenOracledata, data);
        vm.stopPrank();
    }

    /// @notice only owner can set oracle
    function test_set_tap_oracle_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        bytes memory _data = abi.encode(uint256(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionBroker.setTapOracle(tapOracleMock, _data);
        vm.stopPrank();
    }

    /// @notice oracle is correctly set
    function test_set_tap_oracle() public {
        //ok
        vm.startPrank(owner);
        bytes memory _data = abi.encode(uint256(2));
        tapiocaOptionBroker.setTapOracle(tapOracleMock, _data);
        ITapiocaOracle _oracle = tapiocaOptionBroker.tapOracle();
        bytes memory data = tapiocaOptionBroker.tapOracleData();
        assertEq(address(_oracle), address(tapOracleMock));
        assertEq(data, _data);
        vm.stopPrank();
    }

    /// @notice only owner can set token beneficiary
    function test_payment_token_benficiary_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        address user1 = address(0x01);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionBroker.setPaymentTokenBeneficiary(user1);
        vm.stopPrank();
    }

    /// @notice only owner can remove payment tokens from the broker
    function test_collect_payment_tokens_not_owner() public {
        //ok

        vm.startPrank(tokenBeneficiary);
        address[] memory tokens = new address[](2);
        tokens[0] = address(0x01);
        tokens[1] = address(0x02);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tapiocaOptionBroker.collectPaymentTokens(tokens);
        vm.stopPrank();
    }

    /// @notice paymentTokenBeneficiary receives tokens from broker   
    function test_collect_payments() public {
        //ok

        vm.startPrank(owner);
        tapiocaOptionBroker.setPaymentTokenBeneficiary(address(owner));
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);
        //check balances of tokens before and after
        uint256 balanceBeforeAirdrop = mockToken.balanceOf(address(tapiocaOptionBroker));
        uint256 balanceBeforeOwner = mockToken.balanceOf(address(owner));
        tapiocaOptionBroker.collectPaymentTokens(tokens);
        uint256 balanceAfterAirdrop = mockToken.balanceOf(address(tapiocaOptionBroker));
        uint256 balanceAfterOwner = mockToken.balanceOf(address(owner));
        assertEq(balanceBeforeAirdrop + balanceBeforeOwner, balanceAfterOwner + balanceAfterAirdrop); //NOTE this is counting no fee-on-transfer tokens
        assertEq(balanceAfterOwner, balanceBeforeOwner + balanceBeforeAirdrop);
        assertEq(balanceAfterAirdrop, 0);
        vm.stopPrank();
    }

    /// @notice epochs must be > 7 days
    function test_new_epoch_too_soon() public {
        vm.warp(block.timestamp + 6 days);
        vm.expectRevert(TooSoon.selector);
        tapiocaOptionBroker.newEpoch();
    }

    /// @notice there must be at least one singularity to start a new epoch
    function test_new_epoch_no_singularities() public {
        vm.warp(block.timestamp + 7 days + 1 seconds);
        vm.expectRevert(NoActiveSingularities.selector);
        tapiocaOptionBroker.newEpoch();
        //NOTE does not work because epoch is not really true, check dfferences between brokers
    }

    /// @notice new epoch is correctly set when there are singularities
    function test_new_epoch_with_singularities() public {
        vm.startPrank(owner);
        vm.warp(block.timestamp + 7 days + 1 seconds);
        uint256[] memory singularites = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularites.length, 0);
        tapiocaOptionLiquidityProvision.registerSingularity(singularity, 1, 1);
        uint256[] memory singularitesAfter = tapiocaOptionLiquidityProvision.getSingularities();
        assertEq(singularitesAfter.length, 1);
        assertEq(singularitesAfter[0], 1);

        //setMinter role to tapiocaOptionBroker
        aTapOFT.setMinter(address(tapiocaOptionBroker));
        address _minter = aTapOFT.minter();
        assertEq(_minter, address(tapiocaOptionBroker));
        vm.stopPrank();

        vm.startPrank(address(tapiocaOptionBroker));
        // init emissions so that aTapOFT can be emitted in call to newEpoch
        aTapOFT.initEmissions(); 
        vm.stopPrank();

        vm.startPrank(owner);
        //setOracle
        bytes memory _data = abi.encode(uint256(2));
        tapiocaOptionBroker.setTapOracle(tapOracleMock, _data);

        uint256 _epoch = tapiocaOptionBroker.epoch();
        tapiocaOptionBroker.newEpoch();
        uint256 new_epoch = tapiocaOptionBroker.epoch();
        assertEq(new_epoch, _epoch + 1);

        vm.stopPrank();
    }
}
