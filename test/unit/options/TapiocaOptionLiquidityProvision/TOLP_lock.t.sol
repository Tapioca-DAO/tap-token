// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20} from "./TolpBaseTest.sol";

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
        uint256 snapshot = vm.snapshot();
        uint128 lockDuration = uint128(tolp.EPOCH_DURATION());

        _lock(1, uint256(lockDuration));
        vm.revertTo(snapshot);

        _lock(1e8, uint256(lockDuration * 50));
        vm.revertTo(snapshot);

        _lock(1e18, uint256(lockDuration * 100));
        vm.revertTo(snapshot);

        _lock(1000e18, uint256(lockDuration * 1000));
        vm.revertTo(snapshot);
    }

    function _lock(uint256 _deposit, uint256 _lockDuration) internal {
        // it should lock the tokens
        yieldBox.depositAsset(1, aliceAddr, _deposit);
        vm.startPrank(aliceAddr);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(1155, address(yieldBox), 1, address(tolp), type(uint200).max, uint48(block.timestamp + 1));

        vm.expectEmit(true, true, true, false);
        emit Mint(aliceAddr, 1, address(0x1), 0, 0, 0);
        tolp.lock(aliceAddr, IERC20(address(0x1)), uint128(_lockDuration), uint128(_deposit));
        assertEq(tolp.balanceOf(aliceAddr), 1, "TOLP_lock: Invalid balance");
        vm.stopPrank();
    }
}
