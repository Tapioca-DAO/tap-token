// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, IERC20, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TOB_getOTCDealDetails is TobBaseTest {
    function test_RevertWhen_OptionExpired() external setupAndParticipate(aliceAddr, 100, 0) skipEpochs(2) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OptionExpired.selector);
        tob.getOTCDealDetails(1, ERC20(address(0x1)), 1);
    }

    function test_RevertWhen_PaymentTokenNotSupported() external setupAndParticipate(aliceAddr, 100, 0) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.PaymentTokenNotSupported.selector);
        tob.getOTCDealDetails(1, ERC20(address(0x1)), 1);
    }

    function test_RevertWhen_InEpochCooldown() external setDaiMockPaymentToken setupAndParticipate(aliceAddr, 100, 0) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OneEpochCooldown.selector);
        tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1);
    }

    function test_RevertWhen_TapAmountBiggerThanEligible()
        external
        setDaiMockPaymentToken
        setupAndParticipate(aliceAddr, 100, 0)
        skipEpochs(1)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TooHigh.selector);
        tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e50);
    }

    function test_RevertWhen_TapAmountLessThan1()
        external
        setDaiMockPaymentToken
        setupAndParticipate(aliceAddr, 100, 0)
        skipEpochs(1)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TooHigh.selector);
        tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e50);
    }

    function test_ShouldReturnTheRightOTCDealDetails()
        external
        setDaiMockPaymentToken
        setupAndParticipate(aliceAddr, 100, 0)
        skipEpochs(1)
    {
        // it should return the right OTC deal details
        (,, uint128 discount,) = otap.options(1);
        uint256 discountedPrice = TAP_INIT_PRICE - (discount * TAP_INIT_PRICE / 100e4);

        (uint256 eligibleTapAmount, uint256 paymentTokenAmount, uint256 tapAmount) =
            tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e18);

        assertGt(eligibleTapAmount, 0, "TOB_getOTCDealDetails: Invalid eligible tap amount");
        assertEq(paymentTokenAmount, discountedPrice, "TOB_getOTCDealDetails: Invalid payment token amount");
        assertEq(tapAmount, 1e18, "TOB_getOTCDealDetails: Invalid tap amount");
    }
}
