// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20, ICluster} from "./TolpBaseTest.t.sol";

contract TOLP_ownerActions is TolpBaseTest {
    function test_WhenNotOwner() external {
        // it should revert on setCluster
        vm.expectRevert("Ownable: caller is not the owner");
        tolp.setCluster(ICluster(address(0x1)));

        // it should revert on setPause
        vm.expectRevert(NotAuthorized.selector);
        tolp.setPause(true);

        // it should revert on setEmergencySweepCooldown
        vm.expectRevert("Ownable: caller is not the owner");
        tolp.setEmergencySweepCooldown(1);

        // it should revert on emergencySweep
        vm.expectRevert("Ownable: caller is not the owner");
        tolp.activateEmergencySweep();

        // it should revert on activateEmergencySweep
        vm.expectRevert("Ownable: caller is not the owner");
        tolp.activateEmergencySweep();

        // it should revert on emergencySweep
        vm.expectRevert("Ownable: caller is not the owner");
        tolp.emergencySweep();
    }

    function test_WhenNoRightRole() external {
        // it should revert on emergencySweep
        vm.startPrank(adminAddr);

        tolp.setEmergencySweepCooldown(0);
        tolp.activateEmergencySweep();
        vm.expectRevert(NotAuthorized.selector);
        tolp.emergencySweep();
    }

    function test_WhenRightRole() external {
        vm.startPrank(adminAddr);

        // it should set the cluster
        uint256 snapshotId = vm.snapshot();
        tolp.setCluster(ICluster(address(0x1)));
        vm.revertTo(snapshotId);

        // it should set the pause
        tolp.setPause(true);

        // it should set the emergency sweep cooldown
        tolp.setEmergencySweepCooldown(1);

        //it should revert on activateEmergencySweep
        tolp.activateEmergencySweep();

        // it should set the emergency sweep
        vm.warp(block.timestamp + 1);
        tolp.cluster().setRoleForContract(adminAddr, keccak256("TOLP_EMERGENCY_SWEEP"), true);
        tolp.emergencySweep();
    }
}
