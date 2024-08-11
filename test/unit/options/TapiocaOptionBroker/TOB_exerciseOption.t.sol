// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {
    TapiocaOptionBroker,
    ITapiocaOracle,
    TobBaseTest,
    ERC20Mock,
    IERC20
} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/console.sol";

contract TOB_exerciseOption is TobBaseTest {
    address constant NON_EXISTING_PAYMENT_TOKEN = address(0x1);

    /**
     * MODIFIERS
     */
    modifier whenPearlmitTransferApproved(address _user, address _paymentToken, uint256 _amount) {
        _whenPearlmitTransferApproved(_user, _paymentToken, _amount);
        _;
    }

    modifier whenAmountToExerciseCapped() {
        _;
    }

    function _whenPearlmitTransferApproved(address _user, address _paymentToken, uint256 _amount) internal {
        vm.startPrank(_user);
        ERC20(_paymentToken).approve(address(pearlmit), _amount);
        pearlmit.approve(20, _paymentToken, 0, address(tob), uint200(_amount), uint48(block.timestamp + 1));
        vm.stopPrank();
    }

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

    function test_RevertWhen_OptionIsExpired(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
        skipEpochs(2)
        whenNotPaused
    {
        console.log(__tOLPLockAmount);
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.OptionExpired.selector);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenOptionIsNotExpired() {
        _;
    }

    function test_RevertWhen_PaymentTokenOracleIsNotSet(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
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

    function test_RevertWhen_CallerIsNotAuthorized(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
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

    function test_RevertWhen_EpochIsNotAdvanced(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
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

    function test_RevertWhen_OptionIsInCooldown(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
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

    function test_RevertWhen_TapAmountToBuyIsLowerThan1e18(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
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

    function test_WhenTapAmountIsEqualTo0(uint128 __tOLPLockAmount)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenEpochIsAdvanced
        whenOptionIsNotInCooldown
        whenCallerIsAuthorized
    {
        // it should not revert
        // it should emits `ExerciseOption` with max eligible tap as chosen amount
        uint256 amountToExercise = 0;
        (uint256 eligibleAmount, uint256 paymentTokenAmount,) =
            tob.getOTCDealDetails(1, ERC20(address(daiMock)), amountToExercise);

        _paymentTokenMintAndApprove(aliceAddr, daiMock, paymentTokenAmount);

        vm.expectEmit(true, true, true, true);
        emit TapiocaOptionBroker.ExerciseOption(1, aliceAddr, ERC20(daiMock), 1, eligibleAmount);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    modifier whenTapAmountToBuyIsBiggerThan1e18() {
        _;
    }

    function test_WhenPaymentTokenOracleFailsToFetch(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenOptionIsNotInCooldown
        whenEpochIsAdvanced
        whenTapAmountToBuyIsBiggerThan1e18
        whenAmountToExerciseCapped
        whenCallerIsAuthorized
    {
        amountToExercise = _boundTapAmount(amountToExercise);
        // it reverts
        _resetPrank({caller: adminAddr});
        tob.setPaymentToken(ERC20(address(daiMock)), ITapiocaOracle(address(failingOracleMock)), bytes("420"));
        _resetPrank({caller: aliceAddr});

        vm.expectRevert(TapiocaOptionBroker.Failed.selector);
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
    }

    function test_WhenPaymentTokenOracleSucceedToFetch(uint128 __tOLPLockAmount, uint256 amountToExercise)
        external
        assumeGt(__tOLPLockAmount, 0)
        setupAndParticipate(aliceAddr, __tOLPLockAmount, uint128(tob.EPOCH_DURATION()))
        whenNotPaused
        whenOptionIsNotExpired
        whenPaymentTokenOracleIsSet
        whenEpochIsAdvanced
        whenOptionIsNotInCooldown
        whenTapAmountToBuyIsBiggerThan1e18
        whenAmountToExerciseCapped
        whenCallerIsAuthorized
    {
        amountToExercise = _boundTapAmount(amountToExercise);

        (uint256 eligibleAmount, uint256 paymentTokenAmount,) =
            tob.getOTCDealDetails(1, ERC20(address(daiMock)), amountToExercise);
        _paymentTokenMintAndApprove(aliceAddr, daiMock, paymentTokenAmount);

        // it emits `ExerciseOption`
        tob.exerciseOption({_oTAPTokenID: 1, _paymentToken: ERC20(address(daiMock)), _tapAmount: amountToExercise});
        // it sends TAP from the tOB to the `msg.sender`
        assertEq(
            tapOFT.balanceOf(address(aliceAddr)),
            amountToExercise,
            "TOB_exerciseOption::test_WhenPaymentTokenOracleSucceedToFetch: Invalid TAP balance for Alice"
        );

        // it update the exercised amount of the option for the epoch
        assertEq(
            tob.oTAPCalls(1, 1),
            amountToExercise,
            "TOB_exerciseOption::test_WhenPaymentTokenOracleSucceedToFetch: Invalid exercised amount of the option for the epoch"
        );
    }

    function _paymentTokenMintAndApprove(address _user, ERC20Mock _paymentToken, uint256 _amount) internal {
        _whenPearlmitTransferApproved(_user, address(_paymentToken), _amount); // Pearlmit approve payment tokens to tOB
        _resetPrank({caller: adminAddr});
        daiMock.mintTo(_user, _amount);
        vm.startPrank(_user); // Caller is authorized
    }

    function _boundTapAmount(uint256 _tapAmount) internal returns (uint256) {
        (uint256 eligibleAmount,,) = tob.getOTCDealDetails(1, ERC20(address(daiMock)), 0);
        return bound(_tapAmount, 1e18, eligibleAmount);
    }
}
