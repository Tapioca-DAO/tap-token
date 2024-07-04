// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {
    UnitBaseTest,
    TapiocaOptionLiquidityProvision,
    YieldBox1155Mock,
    Pearlmit,
    IPearlmit
} from "../../UnitBaseTest.t.sol";
import {SingularityPool} from "contracts/options/TapiocaOptionLiquidityProvision.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function setUp() public {
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
     * @dev Set the last pool in rescue mode
     */
    modifier setPoolRescue() {
        vm.startPrank(adminAddr);
        tolp.setRescueCooldown(0);
        tolp.requestSglPoolRescue(5);
        tolp.activateSGLPoolRescue(IERC20(address(0x5)));
        vm.stopPrank();
        _;
    }
}
