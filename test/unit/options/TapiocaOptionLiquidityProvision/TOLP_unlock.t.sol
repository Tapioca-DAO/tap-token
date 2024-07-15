// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20} from "./TolpBaseTest.sol";

contract TOLP_unlock is TolpBaseTest {
    function test_ShouldUnlockTheTokens() external registerSingularityPool createLock(1) {
        // it should unlock the tokens
        vm.startPrank(aliceAddr);
        vm.warp(block.timestamp + 7 days);

        vm.expectEmit(true, true, true, true);
        emit Burn(aliceAddr, 1, address(0x1), 1);
        tolp.unlock(1, IERC20(address(0x1)));

        assertEq(tolp.balanceOf(aliceAddr), 0, "TOLP_unlock::test_ShouldUnlockTheTokens: Invalid balance");
        assertEq(
            yieldBox.balanceOf(aliceAddr, 1), 1, "TOLP_unlock::test_ShouldUnlockTheTokens: Invalid yieldBox balance"
        );
        vm.stopPrank();
    }

    function test_RevertWhen_PositionExpired() external registerSingularityPool createLock(1) {
        // it should revert
        vm.startPrank(aliceAddr);
        vm.warp(block.timestamp + 7 days);
        tolp.unlock(1, IERC20(address(0x1)));

        vm.expectRevert(PositionExpired.selector);
        tolp.unlock(1, IERC20(address(0x1)));
        vm.stopPrank();
    }

    function test_RevertWhen_TokenOwnerIsTob() external registerSingularityPool createLock(1) {
        // it should revert
        vm.prank(adminAddr);
        tolp.setTapiocaOptionBroker(address(0x22));
        vm.startPrank(aliceAddr);
        tolp.transferFrom(aliceAddr, address(0x22), 1);

        vm.expectRevert(TobIsHolder.selector);
        tolp.unlock(1, IERC20(address(0x1)));
        vm.stopPrank();
    }

    function test_WhenSglIsInRescue() external registerSingularityPool setPoolRescue createLock(1) {
        // it should make the unlock regarding of time
        vm.startPrank(aliceAddr);
        vm.warp(block.timestamp + 7 days);
        tolp.unlock(1, IERC20(address(0x1)));

        assertEq(tolp.balanceOf(aliceAddr), 0, "TOLP_unlock::test_WhenSglIsInRescue: Invalid balance");
        assertEq(yieldBox.balanceOf(aliceAddr, 1), 1, "TOLP_unlock::test_WhenSglIsInRescue: Invalid yieldBox balance");
        vm.stopPrank();
    }

    modifier whenSglIsNotInRescue() {
        _;
    }

    function test_RevertWhen_LockIsNotExpired() external whenSglIsNotInRescue registerSingularityPool createLock(1) {
        // it should revert
        vm.startPrank(aliceAddr);

        // Lock not expired
        vm.expectRevert(LockNotExpired.selector);
        tolp.unlock(1, IERC20(address(0x1)));
        vm.stopPrank();
    }
}
