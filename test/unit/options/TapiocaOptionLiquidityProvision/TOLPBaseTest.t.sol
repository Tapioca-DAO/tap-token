// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {UnitBaseTest, TapiocaOptionLiquidityProvision, YieldBox, Pearlmit, IPearlmit} from "../../UnitBaseTest.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SingularityPool} from "contracts/options/TapiocaOptionLiquidityProvision.sol";

contract TolpBaseTest is UnitBaseTest {
    TapiocaOptionLiquidityProvision public tolp;
    YieldBox public yieldBox;
    Pearlmit public pearlmit;

    function setUp() public {
        pearlmit = createPearlmit(adminAddr);
        yieldBox = createYieldBox(pearlmit, adminAddr);
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
