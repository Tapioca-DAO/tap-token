// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20, SingularityPool} from "./TolpBaseTest.sol";

contract TOLP_activateSGLPoolRescue is TolpBaseTest {
    function test_ShouldSetRescueToTrue() external registerSingularityPool {
        // it should set rescue to true
        vm.startPrank(adminAddr);

        tolp.requestSglPoolRescue(ybAssetIdToftSglEthMarket);
        vm.warp(block.timestamp + tolp.rescueCooldown());
        tolp.activateSGLPoolRescue(IERC20(address(toftSglEthMarket)));
        (,,, bool rescue) = tolp.activeSingularities(IERC20(address(toftSglEthMarket)));
        assertEq(rescue, true, "TOLP_activateSGLPoolRescue: Invalid rescue");
    }

    function test_RevertWhen_SglAssetIdIs0() external {
        // it should revert
        vm.startPrank(adminAddr);

        vm.expectRevert(NotRegistered.selector);
        tolp.activateSGLPoolRescue(IERC20(address(toftSglEthMarket)));
    }

    function test_RevertWhen_SglRescueIsTrue() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);

        tolp.requestSglPoolRescue(ybAssetIdToftSglEthMarket);
        vm.warp(block.timestamp + tolp.rescueCooldown());
        tolp.activateSGLPoolRescue(IERC20(address(toftSglEthMarket)));
        vm.expectRevert(AlreadyActive.selector);
        tolp.activateSGLPoolRescue(IERC20(address(toftSglEthMarket)));
    }

    function test_RevertWhen_SglRescueRequestIs0() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);

        vm.expectRevert(NotActive.selector);
        tolp.activateSGLPoolRescue(IERC20(address(toftSglEthMarket)));
    }

    function test_RevertWhen_RescueCooldownNotMet() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);

        tolp.requestSglPoolRescue(ybAssetIdToftSglEthMarket);
        vm.expectRevert(RescueCooldownNotReached.selector);
        tolp.activateSGLPoolRescue(IERC20(address(toftSglEthMarket)));
    }
}
