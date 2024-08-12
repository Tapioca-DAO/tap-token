// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, IERC20, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TWAML} from "contracts/options/twAML.sol";


contract TOB_getOTCDealDetails is TobBaseTest, TWAML {
    modifier whenLockingAndParticipating(uint128 _lockAmount, uint128 _lockDuration) {
        (_lockAmount, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _setupAndParticipate(aliceAddr, _lockAmount, _lockDuration);
        _;
    }

    function test_RevertWhen_OptionExpired(uint128 _lockAmount, uint128 _lockDuration) external {
        (_lockAmount, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _setupAndParticipate(aliceAddr, _lockAmount, _lockDuration);
        _skipEpochs((_lockDuration / tob.EPOCH_DURATION()) + 1);

        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OptionExpired.selector);
        tob.getOTCDealDetails(1, ERC20(address(daiMock)), 0);
    }

    function test_RevertWhen_PaymentTokenNotSupported(uint128 _lockAmount, uint128 _lockDuration)
        external
        whenLockingAndParticipating(_lockAmount, _lockDuration)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.PaymentTokenNotSupported.selector);
        tob.getOTCDealDetails(1, ERC20(address(0x1)), 0);
    }

    function test_RevertWhen_InEpochCooldown(uint128 _lockAmount, uint128 _lockDuration)
        external
        setDaiMockPaymentToken
        whenLockingAndParticipating(_lockAmount, _lockDuration)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OneEpochCooldown.selector);
        tob.getOTCDealDetails(1, ERC20(address(daiMock)), 0);
    }

    function test_RevertWhen_TapAmountBiggerThanEligible(uint128 _lockAmount, uint128 _lockDuration)
        external
        setDaiMockPaymentToken
        whenLockingAndParticipating(_lockAmount, _lockDuration)
        skipEpochs(1)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TooHigh.selector);
        tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e50);
    }

    function test_RevertWhen_TapAmountLessThan1(uint128 _lockAmount, uint128 _lockDuration)
        external
        setDaiMockPaymentToken
        whenLockingAndParticipating(_lockAmount, _lockDuration)
        skipEpochs(1)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TooLow.selector);
        tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1);
    }

    function test_ShouldReturnTheRightOTCDealDetails(uint128 _lockAmount, uint128 _lockDuration, uint256 _tapAmount)
        external
        setDaiMockPaymentToken
        whenLockingAndParticipating(_lockAmount, _lockDuration)
        skipEpochs(1)
    {
        // it should return the right OTC deal details
        (,, uint128 discount,) = otap.options(1);
        uint256 discountedPrice = TAP_INIT_PRICE - (discount * TAP_INIT_PRICE / 100e4);

        (uint256 eligibleTapAmount, uint256 paymentTokenAmount, uint256 tapAmount) =
            tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e18);

        assertGt(eligibleTapAmount, 0, "TOB_getOTCDealDetails: Invalid eligible tap amount");
        assertApproxEqAbs(
            paymentTokenAmount, discountedPrice, 10, "TOB_getOTCDealDetails: Invalid payment token amount"
        );
        assertEq(tapAmount, 1e18, "TOB_getOTCDealDetails: Invalid tap amount");
    }
}
