// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

/**
 * External
 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * Core
 */
import {
    TolpBaseTest,
    IERC20,
    SingularityPool,
    IPearlmit,
    ICluster
} from "test/unit/options/TapiocaOptionLiquidityProvision/TolpBaseTest.sol";
import {ITapiocaOracle} from "tap-utils/interfaces/periph/ITapiocaOracle.sol";
import {TapiocaOptionBroker, OTAP} from "test/unit/UnitBaseTest.sol";
import {OracleMock} from "tapioca-mocks/OracleMock.sol";
import {ERC20Mock} from "tapioca-mocks/ERC20Mock.sol";

/**
 * Tests
 */
import {TapTokenMock} from "test/TapTokenMock.sol";
import {FailingOracleMock} from "test/mocks/FailingOracleMock.sol";

contract TobBaseTest is TolpBaseTest {
    TapiocaOptionBroker public tob;
    TapTokenMock public tapOFT;
    OTAP public otap;

    ERC20Mock public daiMock;
    ERC20Mock public usdcMock;
    OracleMock public tapOracleMock;
    OracleMock public daiOracleMock;
    FailingOracleMock public failingOracleMock;

    // Constants
    uint256 public EPOCH_DURATION = 1 weeks;
    uint256 public TAP_INIT_PRICE = 33e17; // $3.3

    // Addresses
    address public PAYMENT_TOKEN_RECEIVER = address(bytes20(keccak256("PAYMENT_TOKEN_RECEIVER")));
    address public TAP_CONTRIBUTOR = address(bytes20(keccak256("TAP_CONTRIBUTOR")));
    address public TAP_EARLY_SUPPORTERS = address(bytes20(keccak256("TAP_EARLY_SUPPORTERS")));
    address public TAP_SUPPORTERS = address(bytes20(keccak256("TAP_SUPPORTERS")));
    address public TAP_LBP = address(bytes20(keccak256("TAP_LBP")));
    address public TAP_DAO = address(bytes20(keccak256("TAP_DAO")));
    address public TAP_AIRDROP = address(bytes20(keccak256("TAP_AIRDROP")));

    function setUp() public virtual override {
        super.setUp();

        /**
         * Deploy contracts
         */
        failingOracleMock = new FailingOracleMock();
        tapOracleMock = new OracleMock("TAP_ORACLE", "TAP_ORACLE", TAP_INIT_PRICE);
        vm.label(address(tapOracleMock), "TAP_ORACLE");
        daiOracleMock = new OracleMock("DAI_ORACLE", "DAI_ORACLE", 1e18); // $1
        vm.label(address(daiOracleMock), "DAI_ORACLE");
        daiMock = new ERC20Mock("DAI", "DAI", 100e18, 18, adminAddr);
        vm.label(address(daiMock), "DAI");
        usdcMock = new ERC20Mock("USDC", "USDC", 100e6, 6, adminAddr);
        vm.label(address(usdcMock), "USDC");

        tapOFT = createTapOftInstance(
            EPOCH_DURATION,
            ENDPOINT_A,
            TAP_CONTRIBUTOR,
            TAP_EARLY_SUPPORTERS,
            TAP_SUPPORTERS,
            TAP_LBP,
            TAP_DAO,
            TAP_AIRDROP,
            EID_A,
            adminAddr
        );
        otap = createOtapInstance(IPearlmit(address(pearlmit)), adminAddr);

        tob = createTobInstance(
            address(tolp),
            address(otap),
            payable(tapOFT),
            PAYMENT_TOKEN_RECEIVER,
            EPOCH_DURATION,
            IPearlmit(address(pearlmit)),
            adminAddr
        );

        /**
         * Set up contracts
         */
        vm.startPrank(adminAddr);
        tob.setCluster(ICluster(address(cluster)));
        tob.setTapOracle(ITapiocaOracle(address(tapOracleMock)), bytes(""));
        tob.setPaymentToken(ERC20(address(daiMock)), ITapiocaOracle(address(daiOracleMock)), bytes(""));
        tob.setPaymentToken(ERC20(address(usdcMock)), ITapiocaOracle(address(daiOracleMock)), bytes(""));
        tapOFT.setMinter(address(tob));
        cluster.setRoleForContract(adminAddr, keccak256("NEW_EPOCH"), true);
        vm.stopPrank();
    }

    modifier tobInit() {
        tob.init();
        _;
    }

    modifier tobAdvanceEpoch() {
        vm.prank(adminAddr);
        tob.newEpoch();
        _;
    }

    modifier tobParticipate(address _user, uint256 _amount, uint128 _lockDuration) {
        _tobParticipate(_user, uint200(_amount), _lockDuration);
        _;
    }

    modifier setupAndParticipate(address _user, uint256 _amount, uint128 _lockDuration) {
        _setupAndParticipate(_user, uint200(_amount), _lockDuration);
        _;
    }

    function _setupAndParticipate(address _user, uint256 _amount, uint128 _lockDuration)
        internal
        registerSingularityPool
        tobInit
        tobParticipate(_user, _amount, _lockDuration)
    {}

    /**
     * @dev Asset ID of the tOLP lock is 1
     */
    function _tobParticipate(address _user, uint200 _amount, uint128 _lockDuration)
        internal
        createLock(_user, _amount, _lockDuration)
    {
        vm.startPrank(_user);
        tolp.approve(address(pearlmit), 1);
        pearlmit.approve(721, address(tolp), 1, address(tob), 1, uint48(block.timestamp + 1));
        tob.participate(1);
        vm.stopPrank();
    }

    modifier setDaiMockPaymentToken() {
        vm.prank(adminAddr);
        tob.setPaymentToken(ERC20(address(daiMock)), ITapiocaOracle(address(daiOracleMock)), bytes(""));
        _;
    }

    modifier skipEpochs(uint256 _epochs) {
        _skipEpochs(_epochs);
        _;
    }

    function _skipEpochs(uint256 _epochs) internal {
        vm.startPrank(adminAddr);
        for (uint256 i = 0; i < _epochs; i++) {
            vm.warp(block.timestamp + 1 weeks);
            tob.newEpoch();
        }
        vm.stopPrank();
    }

    function _boundValues(uint128 _lockAmount, uint128 _lockDuration) internal returns (uint128, uint128) {
        _lockAmount = uint128(bound(_lockAmount, 1e18, 1e40));
        _lockDuration = uint128(tob.EPOCH_DURATION() * bound(_lockDuration, 1, 4));
        return (_lockAmount, _lockDuration);
    }
}
