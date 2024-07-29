// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, IERC20, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";

contract TOB_exerciseOption is TobBaseTest {
    address constant NON_EXISTING_PAYMENT_TOKEN = address(0x1);

    error PermitC__ApprovalTransferPermitExpiredOrUnset();

    function test_RevertWhen_OptionExpired() external setupAndParticipate(aliceAddr, 100, 1) skipEpochs(2) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OptionExpired.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_PaymentTokenNotSupported() external setupAndParticipate(aliceAddr, 100, 1) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.PaymentTokenNotSupported.selector);
        tob.exerciseOption(1, ERC20(address(0x1)), 1e18);
    }

    function test_RevertWhen_CallerNotOwnerOrNotApproved() external setupAndParticipate(aliceAddr, 100, 1) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_EpochNotAdvanced() external setupAndParticipate(aliceAddr, 100, 1) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_OptionIsInCooldown1() external setupAndParticipate(aliceAddr, 100, 1) {
        // it should revert
        vm.startPrank(aliceAddr);

        vm.expectRevert(TapiocaOptionBroker.OneEpochCooldown.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_NoLiquidity() external setupAndParticipate(aliceAddr, 100, 1) {
        // it should revert
        vm.skip(true); // Check comment on revert part
    }

    function test_RevertWhen_ExercisingAboveTheEligibleAmount()
        external
        setupAndParticipate(aliceAddr, 100, 1)
        skipEpochs(1)
    {
        // it should revert
        vm.startPrank(aliceAddr);
        (uint256 eligibleTapAmount,,) = tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e18);

        vm.expectRevert(TapiocaOptionBroker.TooHigh.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), eligibleTapAmount + 1);
    }

    function test_RevertWhen_ExercisingBelowTheMinimumAmount()
        external
        setupAndParticipate(aliceAddr, 100, 1)
        skipEpochs(1)
    {
        // it should revert
        vm.startPrank(aliceAddr);

        vm.expectRevert(TapiocaOptionBroker.TooLow.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18 - 1);
    }

    function test_RevertWhen_PearlmitTransferFailed() external setupAndParticipate(aliceAddr, 100, 1) skipEpochs(1) {
        // it should revert
        vm.startPrank(aliceAddr);

        vm.expectRevert(PermitC__ApprovalTransferPermitExpiredOrUnset.selector);
        tob.exerciseOption(1, ERC20(address(daiMock)), 1e18);
    }

    function test_RevertWhen_BalanceAfterNotMatching() external setupAndParticipate(aliceAddr, 100, 1) skipEpochs(1) {
        // it should revert
        vm.skip(true); // Check comment on revert part
    }

    function test_ShouldExerciseTheOption() external setupAndParticipate(aliceAddr, 100, 1) skipEpochs(1) {
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

    /**
     * MODIFIERS
     */

    /**
     * TESTS
     */

    /// @notice Should revert when the contract is paused
    function test_RevertWhen_Paused(uint256 amountToExercise) external {
        // it should revert
        _resetPrank({caller: adminAddr});
        tob.setPause(true);

        vm.expectRevert("Pausable: paused");
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenNotPaused() {
        _;
    }

    function test_RevertWhen_OptionIsExpired(uint256 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, 1)
        skipEpochs(2)
        whenNotPaused
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OptionExpired.selector);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenOptionIsNotExpired() {
        _;
    }

    function test_RevertWhen_PaymentTokenOracleIsNotSet(uint256 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, 1)
        whenNotPaused
        whenOptionIsNotExpired
    {
        // it should revert
        vm.prank(adminAddr);

        vm.expectRevert(TapiocaOptionBroker.PaymentTokenNotSupported.selector);
        tob.exerciseOption({
            _oTAPTokenID: 1,
            _paymentToken: ERC20(address(NON_EXISTING_PAYMENT_TOKEN)),
            _tapAmount: amountToExercise
        });
    }

    modifier whenPaymentTokenOracleIsSet() {
        _;
    }

    function test_RevertWhen_CallerIsNotAuthorized(uint256 __tOLPLockAmount, uint256 amountToExercise)
        external
        setupAndParticipate(aliceAddr, __tOLPLockAmount, 1)
        assumeGt(__tOLPLockAmount, 0)
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenCallerIsAuthorized() {
        _resetPrank({caller: aliceAddr});
        _;
    }

    function test_RevertWhen_EpochIsNotAdvanced(uint256 __tOLPLockAmount, uint256 amountToExercise)
        external
        setupAndParticipate(aliceAddr, __tOLPLockAmount, 1)
        assumeGt(__tOLPLockAmount, 0)
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenCallerIsAuthorized
    {
        // it should revert
        skip(tob.EPOCH_DURATION());

        vm.expectRevert(TapiocaOptionBroker.AdvanceEpochFirst.selector);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenEpochIsAdvanced() {
        _;
    }

    function test_RevertWhen_OptionIsInCooldown(uint256 __tOLPLockAmount, uint256 amountToExercise)
        external
        setupAndParticipate(aliceAddr, __tOLPLockAmount, 1)
        assumeGt(__tOLPLockAmount, 0)
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenCallerIsAuthorized
        whenEpochIsAdvanced
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OneEpochCooldown.selector);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenOptionIsNotInCooldown() {
        _resetPrank({caller: adminAddr});
        skip(tob.EPOCH_DURATION());
        tob.newEpoch();
        vm.stopPrank();
        _;
    }

    modifier whenTapAmountToBuyIsLowerThan1e18(uint256 value) {
        vm.assume(value < 1e18);
        vm.assume(value > 0);
        _;
    }

    function test_RevertWhen_TapAmountToBuyIsLowerThan1e18(uint256 __tOLPLockAmount, uint256 amountToExercise)
        external
        setupAndParticipate(aliceAddr, __tOLPLockAmount, 1)
        assumeGt(__tOLPLockAmount, 0)
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenEpochIsAdvanced
        whenOptionIsNotInCooldown
        whenCallerIsAuthorized
        whenTapAmountToBuyIsLowerThan1e18(amountToExercise)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TooLow.selector);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    function test_WhenTapAmountIsEqualTo0(uint256 __tOLPLockAmount)
        external
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenCallerIsAuthorized
        whenEpochIsAdvanced
        whenOptionIsNotInCooldown
    {
        // it should not revert
        // it should emits `ExerciseOption` with max eligible tap as chosen amount
        uint256 amountToExercise = 0;
        (uint256 eligibleAmount,,) = tob.getOTCDealDetails(1, ERC20(address(daiMock)), 1e18);

        vm.expectEmit(true, true, true, true);
        emit TapiocaOptionBroker.ExerciseOption(1, aliceAddr, ERC20(daiMock), 1, amountToExercise);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenTapAmountToBuyIsBiggerThan1e18() {
        _;
    }

    function test_WhenPaymentTokenOracleFailsToFetch(uint256 __tOLPLockAmount, uint256 amountToExercise)
        external
        setupAndParticipate(aliceAddr, __tOLPLockAmount, 1)
        assumeGt(__tOLPLockAmount, 0)
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenEpochIsAdvanced
        whenOptionIsNotInCooldown
        whenTapAmountToBuyIsBiggerThan1e18
        whenCallerIsAuthorized
    {
        // it reverts
    }

    function test_WhenPaymentTokenOracleSucceedToFetch()
        external
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenEpochIsAdvanced
        whenOptionIsNotInCooldown
        whenTapAmountToBuyIsBiggerThan1e18
        whenCallerIsAuthorized
    {
        // it update the exercised amount of the option for the epoch
        // it sends TAP from the tOB to the `msg.sender`
        // it emits `ExerciseOption`
    }
}
