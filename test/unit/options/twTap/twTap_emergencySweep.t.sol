// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";

contract twTap_emergencySweep is twTapBaseTest {
    function test_RevertWhen_EmergencyCooldownNotReached() external {
        // it should revert
        vm.startPrank(adminAddr);
        vm.expectRevert(TwTAP.EmergencySweepCooldownNotReached.selector);
        twTap.emergencySweep();
    }

    function test_RevertWhen_NotOwner() external {
        // it should revert
        vm.startPrank(adminAddr);
        twTap.setEmergencySweepCooldown(0);
        twTap.activateEmergencySweep();
        vm.stopPrank();
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.emergencySweep();
    }

    function test_ShouldSweepTheLocks() external participate(1e20, 1) skipWeeks(1) advanceWeeks(1) distributeRewards {
        // it should sweep the locks
        vm.startPrank(adminAddr);
        twTap.setEmergencySweepCooldown(0);
        twTap.activateEmergencySweep();
        twTap.emergencySweep();

        // Test lock sweep
        assertEq(
            twTap.lastEmergencySweep(),
            0,
            "twTap_emergencySweep::test_ShouldSweepTheLocks: Invalid last emergency sweep"
        );
        assertEq(tapOFT.balanceOf(adminAddr), 1e20, "twTap_emergencySweep::test_ShouldSweepTheLocks: Invalid balance");

        // Test rewards sweep

        assertEq(
            daiMock.balanceOf(adminAddr), 1e25, "twTap_emergencySweepRewards::test_ShouldSweepTheLocks: Invalid balance"
        );
        assertEq(
            usdcMock.balanceOf(adminAddr),
            1e13,
            "twTap_emergencySweepRewards::test_ShouldSweepTheLocks: Invalid balance"
        );
    }
}
