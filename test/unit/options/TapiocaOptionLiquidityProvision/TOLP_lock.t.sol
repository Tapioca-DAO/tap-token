// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20} from "./TolpBaseTest.t.sol";

contract TOLP_lock is TolpBaseTest {
    function test_RevertWhen_LockDurationIsLowerThanEpochDuration() external {
        // it should revert
        vm.expectRevert(DurationTooShort.selector);
        vm.prank(aliceAddr);
        tolp.lock(aliceAddr, IERC20(address(0x1)), 1, 1);
    }

    function test_RevertWhen_LockDurationIsGreaterThanMaxLockDuration() external {
        // it should revert
        uint128 lockDuration = uint128(tolp.MAX_LOCK_DURATION()) + 1;
        vm.expectRevert(DurationTooLong.selector);
        vm.prank(aliceAddr);
        tolp.lock(aliceAddr, IERC20(address(0x1)), lockDuration, 1);
    }

    function test_RevertWhen_ShareAre0() external {
        // it should revert
        uint128 lockDuration = uint128(tolp.EPOCH_DURATION());
        vm.expectRevert(SharesNotValid.selector);
        vm.prank(aliceAddr);
        tolp.lock(aliceAddr, IERC20(address(0x1)), lockDuration, 0);
    }

    function test_RevertWhen_SglRescuePoolIsActivated() external registerSingularityPool setPoolRescue {
        // it should revert
        uint128 lockDuration = uint128(tolp.EPOCH_DURATION());
        vm.expectRevert(SingularityInRescueMode.selector);
        vm.prank(aliceAddr);
        tolp.lock(aliceAddr, IERC20(address(0x5)), lockDuration, 1);
    }

    function test_RevertWhen_PearlmitTransferFails() external registerSingularityPool {
        // it should revert
        uint128 lockDuration = uint128(tolp.EPOCH_DURATION());
        vm.startPrank(aliceAddr);
        vm.expectRevert();
        tolp.lock(aliceAddr, IERC20(address(0x1)), lockDuration, 1);
        vm.stopPrank();
    }

    function test_ShouldLockTheTokens() external registerSingularityPool {
        // it should lock the tokens
        uint128 lockDuration = uint128(tolp.EPOCH_DURATION());
        yieldBox.depositAsset(1, aliceAddr, 1);
        vm.startPrank(aliceAddr);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(1155, address(yieldBox), 1, address(tolp), type(uint200).max, uint48(block.timestamp + 1));
        tolp.lock(aliceAddr, IERC20(address(0x1)), lockDuration, 1);
        assertEq(tolp.balanceOf(aliceAddr), 1, "TOLP_lock: Invalid balance");
        vm.stopPrank();
    }
}
