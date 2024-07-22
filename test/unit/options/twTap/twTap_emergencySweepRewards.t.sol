// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";


contract twTap_emergencySweepRewards is twTapBaseTest {
    function test_RevertWhen_EmergencyCooldownNotReached() external {
        // it should revert
        vm.startPrank(adminAddr);
        vm.expectRevert(TwTAP.EmergencySweepCooldownNotReached.selector);
        twTap.emergencySweepRewards();
    }

    function test_RevertWhen_NotOwner() external {
        // it should revert
        vm.startPrank(adminAddr);
        twTap.setEmergencySweepCooldown(0);
        twTap.activateEmergencySweep();
        vm.expectRevert(TwTAP.NotAuthorized.selector);
        twTap.emergencySweepRewards();
    }

    function test_ShouldSweepTheLocks() external  participate(1e20, 1) skipWeeks(1) advanceWeeks(1) distributeRewards {
        // it should sweep the locks
                vm.startPrank(adminAddr);
        twTap.setEmergencySweepCooldown(0);
        twTap.activateEmergencySweep();
        cluster.setRoleForContract(adminAddr, keccak256("TWTAP_EMERGENCY_SWEEP"), true);
        twTap.emergencySweepRewards();

        assertEq(
            twTap.lastEmergencySweep(),
            0,
            "twTap_emergencySweepRewards::test_ShouldSweepTheLocks: Invalid last emergency sweep"
        );
        assertEq(
            daiMock.balanceOf(adminAddr), 1e25, "twTap_emergencySweepRewards::test_ShouldSweepTheLocks: Invalid balance"
        );
        assertEq(
            daiMock.balanceOf(adminAddr), 1e13, "twTap_emergencySweepRewards::test_ShouldSweepTheLocks: Invalid balance"
        );
    }
}
