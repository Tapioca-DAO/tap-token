// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

/**
 * Tap Token core contracts
 */
import {TapiocaOptionLiquidityProvision} from "contracts/options/TapiocaOptionLiquidityProvision.sol";
import {TapiocaOptionBroker} from "contracts/options/TapiocaOptionBroker.sol";
import {TapTokenReceiver} from "contracts/tokens/TapTokenReceiver.sol";
import {TapTokenSender} from "contracts/tokens/TapTokenSender.sol";
import {TwTAP} from "contracts/governance/twTAP.sol";
import {OTAP} from "contracts/options/oTAP.sol";
/**
 * Peripheral contracts
 */
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {Pearlmit, IPearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {IWrappedNative} from "yieldbox/interfaces/IWrappedNative.sol";
import {YieldBox1155Mock} from "tapioca-mocks/YieldBox1155Mock.sol";
import {YieldBoxURIBuilder} from "yieldbox/YieldBoxURIBuilder.sol";
import {Cluster} from "tapioca-periph/Cluster/Cluster.sol";
import {ITapToken} from "contracts/tokens/ITapToken.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";

/**
 * Tests
 */
import {TestHelper} from "test/LZSetup/TestHelper.sol";
import {TapTokenMock} from "test/TapTokenMock.sol";
import "forge-std/Test.sol";

contract UnitBaseTest is TestHelper {
    // Address mapping
    uint256 internal adminPKey = 0x1;
    address public adminAddr = vm.addr(adminPKey);
    uint256 internal alicePKey = 0x2;
    address public aliceAddr = vm.addr(alicePKey);
    uint256 internal bobPKey = 0x3;
    address public bobAddr = vm.addr(bobPKey);

    // Peripheral contracts
    YieldBox1155Mock public yieldBox;
    Pearlmit public pearlmit;
    Cluster public cluster;

    // Constants
    uint32 public EID_A = 1;
    address public ENDPOINT_A;

    uint32 public EID_B = 2;
    address public ENDPOINT_B;

    function setUp() public virtual override {
        vm.label(aliceAddr, "Alice");

        // Peripheral contracts
        pearlmit = createPearlmit(adminAddr);
        yieldBox = createYieldBox1155Mock();
        cluster = createCluster(0, adminAddr);

        // Misc
        vm.warp(10000 weeks); // Set it to a big number

        setUpEndpoints(3, LibraryType.UltraLightNode);
        ENDPOINT_A = address(endpoints[EID_A]);
        ENDPOINT_B = address(endpoints[EID_B]);
    }

    /**
     * Tap Token core contracts
     */
    function createTolpInstance(address _yieldBox, uint256 _epochDuration, IPearlmit _pearlmit, address _owner)
        internal
        returns (TapiocaOptionLiquidityProvision)
    {
        TapiocaOptionLiquidityProvision tolp =
            new TapiocaOptionLiquidityProvision(_yieldBox, _epochDuration, _pearlmit, _owner);

        vm.startPrank(_owner);
        tolp.setCluster(ICluster(address(new Cluster(0, _owner))));
        vm.stopPrank();

        return tolp;
    }

    function createTobInstance(
        address _tOLP,
        address _oTAP,
        address payable _tapOFT,
        address _paymentTokenBeneficiary,
        uint256 _epochDuration,
        IPearlmit _pearlmit,
        address _owner
    ) internal returns (TapiocaOptionBroker) {
        TapiocaOptionBroker tob =
            new TapiocaOptionBroker(_tOLP, _oTAP, _tapOFT, _paymentTokenBeneficiary, _epochDuration, _pearlmit, _owner);

        vm.startPrank(_owner);
        tob.setCluster(ICluster(address(new Cluster(0, _owner))));
        vm.stopPrank();

        return tob;
    }

    function createTapOftInstance(
        uint256 _epochDuration,
        address _endpoint,
        address _contributor,
        address _earlySupporters,
        address _supporters,
        address _lbp,
        address _dao,
        address _airdrop,
        uint256 _governanceEid,
        address _owner
    ) internal returns (TapTokenMock) {
        return new TapTokenMock(
            ITapToken.TapTokenConstructorData(
                _epochDuration,
                _endpoint,
                _contributor,
                _earlySupporters,
                _supporters,
                _lbp,
                _dao,
                _airdrop,
                _governanceEid,
                _owner,
                address(new TapTokenSender("", "", _endpoint, _owner, address(0))),
                address(new TapTokenReceiver("", "", _endpoint, _owner, address(0))),
                address(new TapiocaOmnichainExtExec()),
                IPearlmit(address(pearlmit)),
                ICluster(address(cluster))
            )
        );
    }

    function createOtapInstance(IPearlmit _pearlmit, address _owner) internal returns (OTAP) {
        return new OTAP(_pearlmit, _owner);
    }

    function createTwTap(address payable _tapOft, IPearlmit _pearlmit, address _owner) internal returns (TwTAP) {
        return new TwTAP(_tapOft, _pearlmit, _owner);
    }

    /**
     * Peripheral contracts
     */
    function createPearlmit(address _owner) internal returns (Pearlmit) {
        return new Pearlmit("Pearlmit", "1", _owner, 0);
    }

    function createYieldBox(Pearlmit _pearlmit, address _owner) internal returns (YieldBox) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();
        return new YieldBox(IWrappedNative(address(0)), uriBuilder, _pearlmit, _owner);
    }

    function createYieldBox1155Mock() internal returns (YieldBox1155Mock) {
        return new YieldBox1155Mock();
    }

    function createCluster(uint32 _lzChainId, address _owner) internal returns (Cluster) {
        return new Cluster(_lzChainId, _owner);
    }

    /**
     * UTILS
     */
    function _resetPrank(address caller) internal {
        vm.stopPrank();
        vm.startPrank(caller);
    }

    modifier assumeGt(uint256 a, uint256 b) {
        vm.assume(a > b);
        _;
    }

    modifier assumeLt(uint256 a, uint256 b) {
        vm.assume(a < b);
        _;
    }
}
