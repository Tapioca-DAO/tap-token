// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";

contract twTap_emergencySweepLocks is twTapBaseTest {
    function test_RevertWhen_EmergencyCooldownNotReached() external {
        // it should revert
        vm.startPrank(adminAddr);
        vm.expectRevert(TwTAP.EmergencySweepCooldownNotReached.selector);
        twTap.emergencySweepLocks();
    }

    function test_RevertWhen_NotOwner() external {
        // it should revert
        vm.startPrank(adminAddr);
        twTap.setEmergencySweepCooldown(0);
        twTap.activateEmergencySweep();
        vm.expectRevert(TwTAP.NotAuthorized.selector);
        twTap.emergencySweepLocks();
    }

    function test_ShouldSweepTheLocks() external participate(1e20, 1) {
        // it should sweep the locks
        vm.startPrank(adminAddr);
        twTap.setEmergencySweepCooldown(0);
        twTap.activateEmergencySweep();
        cluster.setRoleForContract(adminAddr, keccak256("TWTAP_EMERGENCY_SWEEP"), true);
        twTap.emergencySweepLocks();

        assertEq(
            twTap.lastEmergencySweep(),
            0,
            "twTap_emergencySweepLocks::test_ShouldSweepTheLocks: Invalid last emergency sweep"
        );
        assertEq(
            tapOFT.balanceOf(adminAddr), 1e20, "twTap_emergencySweepLocks::test_ShouldSweepTheLocks: Invalid balance"
        );
    }
}
