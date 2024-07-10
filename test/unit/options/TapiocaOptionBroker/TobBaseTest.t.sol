// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

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
import {TapiocaOptionBroker, OTAP} from "test/unit/UnitBaseTest.sol";

/**
 * Tests
 */
import {TapTokenMock} from "test/TapTokenMock.sol";

contract TobBaseTest is TolpBaseTest {
    TapiocaOptionBroker public tob;
    TapTokenMock public tapOFT;
    OTAP public otap;

    // Constants
    uint256 public EPOCH_DURATION = 1 weeks;

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
        vm.startPrank(adminAddr);
        tob.setCluster(ICluster(address(cluster)));
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

    modifier tobParticipate() {
        _tobParticipate();
        _;
    }

    /**
     * @dev Asset ID of the tOLP lock is 1
     */
    function _tobParticipate() internal registerSingularityPool createLock {
        vm.startPrank(aliceAddr);
        tolp.approve(address(pearlmit), 1);
        pearlmit.approve(721, address(tolp), 1, address(tob), 1, uint48(block.timestamp + 1));
        tob.participate(1);
        vm.stopPrank();
    }
}
