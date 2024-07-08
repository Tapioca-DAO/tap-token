// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    UnitBaseTest,
    TapiocaOptionLiquidityProvision,
    YieldBox1155Mock,
    Pearlmit,
    IPearlmit,
    ICluster
} from "../../UnitBaseTest.t.sol";
import {SingularityPool} from "contracts/options/TapiocaOptionLiquidityProvision.sol";

contract TolpBaseTest is UnitBaseTest {
    TapiocaOptionLiquidityProvision public tolp;
    YieldBox1155Mock public yieldBox;
    Pearlmit public pearlmit;

    error NotRegistered();
    error InvalidSingularity();
    error DurationTooShort();
    error DurationTooLong();
    error SharesNotValid();
    error SingularityInRescueMode();
    error SingularityNotActive();
    error PositionExpired();
    error LockNotExpired();
    error AlreadyActive();
    error AssetIdNotValid();
    error DuplicateAssetId();
    error AlreadyRegistered();
    error NotAuthorized();
    error NotInRescueMode();
    error NotActive();
    error RescueCooldownNotReached();
    error TransferFailed();
    error TobIsHolder();
    error NotValid();
    error EmergencySweepCooldownNotReached();

    function setUp() public virtual override {
        super.setUp();

        pearlmit = createPearlmit(adminAddr);
        yieldBox = createYieldBox1155Mock();
        tolp = createTolpInstance(address(yieldBox), 7 days, IPearlmit(address(pearlmit)), adminAddr);
    }

    /**
     * @dev Register 5 singularity pools, and set the last one in rescue mode
     */
    modifier registerSingularityPool() {
        vm.startPrank(adminAddr);
        tolp.registerSingularity(IERC20(address(0x1)), 1, 0); // sglAddr, yb assetId, weight
        tolp.registerSingularity(IERC20(address(0x2)), 2, 0);
        tolp.registerSingularity(IERC20(address(0x3)), 3, 0);
        tolp.registerSingularity(IERC20(address(0x4)), 4, 0);
        tolp.registerSingularity(IERC20(address(0x5)), 5, 0);
        vm.stopPrank();
        _;
    }

    /**
     * @dev Set the asset ID 5 in rescue mode
     */
    modifier setPoolRescue() {
        vm.startPrank(adminAddr);
        tolp.setRescueCooldown(0);
        tolp.requestSglPoolRescue(5);
        tolp.activateSGLPoolRescue(IERC20(address(0x5)));
        vm.stopPrank();
        _;
    }

    /**
     * @dev Create a lock for with Alice on asset ID 1
     */
    modifier createLock() {
        uint128 lockDuration = uint128(tolp.EPOCH_DURATION());
        yieldBox.depositAsset(1, aliceAddr, 1);
        vm.startPrank(aliceAddr);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(1155, address(yieldBox), 1, address(tolp), type(uint200).max, uint48(block.timestamp + 1));
        tolp.lock(aliceAddr, IERC20(address(0x1)), lockDuration, 1);
        assertEq(tolp.balanceOf(aliceAddr), 1, "TOLP_lock: Invalid balance");
        vm.stopPrank();
        _;
    }

    modifier setSglInRescue(IERC20 sgl, uint256 assetId) {
        vm.startPrank(adminAddr);
        tolp.requestSglPoolRescue(assetId);
        vm.warp(block.timestamp + tolp.rescueCooldown());
        tolp.activateSGLPoolRescue(sgl);
        vm.stopPrank();
        _;
    }
}
