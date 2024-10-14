// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20} from "./TolpBaseTest.sol";

contract TOLP_setSGLPoolWeight is TolpBaseTest {
    function test_RevertWhen_AssetIdIs0() external {
        // it should revert
        vm.startPrank(adminAddr);
        vm.expectRevert(NotRegistered.selector);
        tolp.setSGLPoolWeight(IERC20(address(toftSglEthMarket)), ybAssetIdToftSglEthMarket);
    }

    function test_ShouldSetTheWeightOfThePool() external registerSingularityPool {
        // it should set the weight of the pool
        vm.startPrank(adminAddr);
        tolp.setSGLPoolWeight(IERC20(address(toftSglEthMarket)), 3);

        (,, uint256 poolWeight,) = tolp.activeSingularities(IERC20(address(toftSglEthMarket)));
        assertEq(poolWeight, 3, "TOLP_setSGLPoolWeight: Invalid weight");
        //     and also update the total weights
        assertEq(tolp.totalSingularityPoolWeights(), 7, "TOLP_setSGLPoolWeight: Invalid total weight");
    }
}
