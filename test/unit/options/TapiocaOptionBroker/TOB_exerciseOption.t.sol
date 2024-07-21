// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, IERC20, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TOB_exerciseOption is TobBaseTest {
    error PermitC__ApprovalTransferPermitExpiredOrUnset();

    function test_RevertWhen_OptionExpired() external setupAndParticipate(100, 1) skipEpochs(2) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OptionExpired.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_PaymentTokenNotSupported() external setupAndParticipate(100, 1) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.PaymentTokenNotSupported.selector);
        tob.exerciseOption(1, ERC20(address(0x1)), 1e18);
    }

    function test_RevertWhen_CallerNotOwnerOrNotApproved() external setupAndParticipate(100, 1) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_EpochNotAdvanced() external setupAndParticipate(100, 1) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_OptionIsInCooldown() external setupAndParticipate(100, 1) {
        // it should revert
        vm.startPrank(aliceAddr);

        vm.expectRevert(TapiocaOptionBroker.OneEpochCooldown.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_NoLiquidity() external setupAndParticipate(100, 1) {
        // it should revert
        vm.skip(true); // Check comment on revert part
    }

    function test_RevertWhen_ExercisingAboveTheEligibleAmount() external setupAndParticipate(100, 1) skipEpochs(1) {
        // it should revert
        vm.startPrank(aliceAddr);
        (uint256 eligibleTapAmount,,) = tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e18);

        vm.expectRevert(TapiocaOptionBroker.TooHigh.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), eligibleTapAmount + 1);
    }

    function test_RevertWhen_ExercisingBelowTheMinimumAmount() external setupAndParticipate(100, 1) skipEpochs(1) {
        // it should revert
        vm.startPrank(aliceAddr);

        vm.expectRevert(TapiocaOptionBroker.TooLow.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18 - 1);
    }

    function test_RevertWhen_PearlmitTransferFailed() external setupAndParticipate(100, 1) skipEpochs(1) {
        // it should revert
        vm.startPrank(aliceAddr);

        vm.expectRevert(PermitC__ApprovalTransferPermitExpiredOrUnset.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_BalanceAfterNotMatching() external setupAndParticipate(100, 1) skipEpochs(1) {
        // it should revert
        vm.skip(true); // Check comment on revert part
    }

    function test_ShouldExerciseTheOption() external setupAndParticipate(100, 1) skipEpochs(1) {
        // it should exercise the option
        vm.startPrank(adminAddr);
        daiMock.mintTo(aliceAddr, 1e25);
        usdcMock.mintTo(aliceAddr, 1e12);
        vm.stopPrank();

        vm.startPrank(aliceAddr);
        uint256 snapshot = vm.snapshot();

        (uint256 eligibleTapAmount,,) = tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e18);
        _exercise(1e18);
        vm.revertTo(snapshot);
        _exercise(eligibleTapAmount);
    }

    function _exercise(uint256 _amount) internal {
        daiMock.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(daiMock), 0, address(tob), type(uint200).max, uint48(block.timestamp + 1));
        tob.exerciseOption(1, ERC20(address(daiMock)), _amount);

        assertEq(
            tapOFT.balanceOf(address(aliceAddr)),
            _amount,
            "TOB_exerciseOption::test_ShouldExerciseTheOption: Invalid TAP balance for Alice"
        );
    }
}
