// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";
import {Participation} from "contracts/governance/twTap.sol";
import {TWAML} from "contracts/options/twAML.sol";

contract twTap_participate is twTapBaseTest, TWAML {
    uint256 constant TWTAP_TOKEN_ID = 1;
    uint256 constant dMIN = 0;
    uint256 constant dMAX = 1_000_000;
    uint256 SEED_EPOCH_DURATION;

    function setUp() public override {
        super.setUp();
        SEED_EPOCH_DURATION = 4 * twTap.EPOCH_DURATION();
    }

    function test_RevertWhen_Paused(uint256 _lockAmount, uint256 _lockDuration) external {
        vm.prank(adminAddr);
        twTap.setPause(true);
        // it should revert
        vm.expectRevert("Pausable: paused");
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_RevertWhen_RescueModeIsActive(uint256 _lockAmount, uint256 _lockDuration) external whenNotPaused {
        vm.prank(adminAddr);
        twTap.setRescueMode(true);
        // it should revert
        vm.expectRevert(TwTAP.RescueModeActive.selector);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    modifier whenRescueModeIsNotActive() {
        _;
    }

    function test_RevertWhen_EmergencySweepActive(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
    {
        vm.prank(adminAddr);
        twTap.activateEmergencySweep();
        // it should revert
        vm.expectRevert(TwTAP.EmergencySweepActivated.selector);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    modifier whenEmergencySweepNotActive() {
        _;
    }

    function test_RevertWhen_LockDurationIsLessThanAWeek(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
    {
        _lockDuration = bound(_lockDuration, 0, twTap.EPOCH_DURATION() - 1);
        // it should revert
        vm.expectRevert(TwTAP.LockNotAWeek.selector);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    /// @notice We use _assume to avoid running a lot of `vm.assume` in future tests
    modifier whenLockDurationIsMoreThanAWeek() {
        _;
    }

    function test_RevertWhen_LockDurationIsMoreThanMaxDuration(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
        whenLockDurationIsMoreThanAWeek
    {
        (_lockAmount,) = _boundValues(_lockAmount, _lockDuration);
        _lockDuration = twTap.EPOCH_DURATION() * bound(_lockDuration, twTap.MAX_LOCK_DURATION(), type(uint88).max);

        // it should revert
        vm.expectRevert(TwTAP.LockTooLong.selector);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    /// @notice We use _assume to avoid running a lot of `vm.assume` in future tests
    modifier whenLockDurationIsLessThanMaxDuration() {
        _;
    }

    function test_RevertWhen_LockDurationIsNotAMultipleOfEpochDuration(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
        whenLockDurationIsMoreThanAWeek
        whenLockDurationIsLessThanMaxDuration
    {
        _lockDuration = twTap.EPOCH_DURATION() + 1;

        // it should revert
        vm.expectRevert(TwTAP.DurationNotMultiple.selector);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    modifier whenLockDurationIsAMultipleOfEpochDuration() {
        _;
    }

    function test_RevertWhen_WeekWasNotAdvanced(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
        whenLockDurationIsMoreThanAWeek
        whenLockDurationIsLessThanMaxDuration
        whenLockDurationIsAMultipleOfEpochDuration
    {
        (_lockAmount, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        skip(twTap.EPOCH_DURATION() * _lockDuration);

        // it should revert
        _lockDuration = _lockDuration * twTap.EPOCH_DURATION();
        vm.expectRevert(TwTAP.AdvanceWeekFirst.selector);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    modifier whenWeekWasAdvanced() {
        _;
    }

    function test_RevertWhen_PearlmitTransferFails(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
        whenLockDurationIsMoreThanAWeek
        whenLockDurationIsLessThanMaxDuration
        whenLockDurationIsAMultipleOfEpochDuration
        whenWeekWasAdvanced
    {
        (_lockAmount, _lockDuration) = _boundValues(_lockAmount, _lockDuration);

        // it should revert
        // It should be TwTap.TransferFailed.selector,
        // for simplicity we use vm.expectRevert() if we don't permit it
        _lockDuration = _lockDuration * twTap.EPOCH_DURATION();
        vm.expectRevert();
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);
    }

    modifier whenPearlmitTransferSucceed() {
        _resetPrank({caller: aliceAddr});

        tapOFT.approve(address(pearlmit), type(uint256).max);
        pearlmit.approve(20, address(tapOFT), 0, address(twTap), type(uint200).max, uint48(block.timestamp + 1));
        _;
    }

    uint256 public constant MAX_REWARD = 1_000_001; // See @TwTap::dMax

    function test_RevertWhen_MinRewardIsNotMet(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
        whenLockDurationIsMoreThanAWeek
        whenLockDurationIsLessThanMaxDuration
        whenLockDurationIsAMultipleOfEpochDuration
        whenWeekWasAdvanced
        whenPearlmitTransferSucceed
    {
        (, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _lockAmount =
            bound(_lockAmount, 1, computeMinWeight(twTap.VIRTUAL_TOTAL_AMOUNT(), twTap.MIN_WEIGHT_FACTOR()) - 1);
        _lockDuration = _lockDuration * twTap.EPOCH_DURATION();
        tapOFT.freeMint(aliceAddr, _lockAmount);
        // it should revert
        vm.expectRevert(TwTAP.MinRewardTooLow.selector);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, MAX_REWARD);
    }

    modifier whenMinRewardIsMet() {
        _;
    }

    function test_WhenLockerDoesNotHaveVotingPower(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
        whenLockDurationIsMoreThanAWeek
        whenLockDurationIsLessThanMaxDuration
        whenLockDurationIsAMultipleOfEpochDuration
        whenWeekWasAdvanced
        whenPearlmitTransferSucceed
        whenMinRewardIsMet
    {
        (, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _lockAmount =
            bound(_lockAmount, 1, computeMinWeight(twTap.VIRTUAL_TOTAL_AMOUNT(), twTap.MIN_WEIGHT_FACTOR()) - 1);

        _resetPrank({caller: aliceAddr});
        tapOFT.freeMint(aliceAddr, _lockAmount);

        // it should participate without changing AML
        _lockDuration = _lockDuration * twTap.EPOCH_DURATION();
        test_WhenItShouldParticipate(_lockAmount, _lockDuration, false);

        (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative) =
            twTap.twAML();

        assertEq(
            totalParticipants, 0, "twTap_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid totalParticipants"
        );
        assertEq(
            averageMagnitude, 0, "twTap_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid averageMagnitude"
        );
        assertEq(totalDeposited, 0, "twTap_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid totalDeposited");
        assertEq(
            cumulative,
            SEED_EPOCH_DURATION,
            "twTap_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid cumulative"
        );
    }

    function test_WhenLockHasVotingPower(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenRescueModeIsNotActive
        whenEmergencySweepNotActive
        whenLockDurationIsMoreThanAWeek
        whenLockDurationIsLessThanMaxDuration
        whenLockDurationIsAMultipleOfEpochDuration
        whenWeekWasAdvanced
        whenPearlmitTransferSucceed
        whenMinRewardIsMet
    {
        (, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _lockAmount = bound(
            _lockAmount, computeMinWeight(twTap.VIRTUAL_TOTAL_AMOUNT(), twTap.MIN_WEIGHT_FACTOR()), type(uint88).max
        );

        _resetPrank({caller: aliceAddr});
        tapOFT.freeMint(aliceAddr, _lockAmount);

        // it should participate and change AML
        _lockDuration = _lockDuration * twTap.EPOCH_DURATION();
        test_WhenItShouldParticipate(_lockAmount, _lockDuration, true);
    }

    function test_WhenItShouldParticipate(uint256 _lockAmount, uint256 _lockDuration, bool _hasVotingPower) internal {
        // it should emit Participate
        vm.expectEmit(true, true, true, false);
        emit TwTAP.Participate(aliceAddr, TWTAP_TOKEN_ID, _lockAmount, 0, _lockDuration);
        twTap.participate(aliceAddr, _lockAmount, _lockDuration, 0);

        // it should update AML if hasVotingPower is true
        uint256 expectedMagnitude = computeMagnitude(_lockDuration, SEED_EPOCH_DURATION);
        // we have (pool.averageMagnitude + expectedMagnitude) / (pool.totalParticipants),
        // at genesis pool.averageMagnitude = 0, pool.totalParticipants = 1
        uint256 expectedAverageMagnitude = expectedMagnitude;
        uint256 expectedCumulative = SEED_EPOCH_DURATION + expectedMagnitude;
        if (_hasVotingPower) {
            (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative) =
                twTap.twAML();
            assertEq(totalParticipants, 1, "twTap_participate::test_WhenItShouldParticipate: Invalid totalParticipants");
            assertEq(
                averageMagnitude,
                expectedAverageMagnitude,
                "twTap_participate::test_WhenItShouldParticipate: Invalid averageMagnitude"
            );
            assertEq(
                totalDeposited, _lockAmount, "twTap_participate::test_WhenItShouldParticipate: Invalid totalDeposited"
            );
            assertEq(
                cumulative, expectedCumulative, "twTap_participate::test_WhenItShouldParticipate: Invalid cumulative"
            );
        }

        // it should create a participation entry
        uint56 expiry;
        uint256 expectedMultiplier;

        // We're splitting the following code into two blocks to avoid stack too deep error
        {
            (
                uint256 averageMagnitudeParticipation,
                bool hasVotingPower,
                bool divergenceForce,
                bool tapReleased,
                uint56 lockedAt,
                ,
                ,
                ,
                ,
            ) = twTap.participants(TWTAP_TOKEN_ID);
            assertEq(
                averageMagnitudeParticipation,
                _hasVotingPower ? expectedAverageMagnitude : 0,
                "twTap_participate::test_WhenItShouldParticipate: Invalid averageMagnitude"
            );
            assertEq(
                hasVotingPower,
                _hasVotingPower,
                "twTap_participate::test_WhenItShouldParticipate: Invalid hasVotingPower"
            );
            assertEq(
                divergenceForce,
                _hasVotingPower,
                "twTap_participate::test_WhenItShouldParticipate: Invalid divergenceForce"
            );
            assertEq(tapReleased, false, "twTap_participate::test_WhenItShouldParticipate: Invalid tapReleased");
            assertEq(lockedAt, block.timestamp, "twTap_participate::test_WhenItShouldParticipate: Invalid lockedAt");
        }

        {
            (,,,,, uint56 _expiry, uint88 tapAmount, uint24 multiplier,,) = twTap.participants(TWTAP_TOKEN_ID);
            expiry = _expiry;

            assertEq(
                expiry,
                _lockDuration + block.timestamp,
                "twTap_participate::test_WhenItShouldParticipate: Invalid expiry"
            );
            assertEq(tapAmount, _lockAmount, "twTap_participate::test_WhenItShouldParticipate: Invalid tapAmount");

            expectedMultiplier = computeTarget(dMIN, dMAX, expectedMagnitude * _lockAmount, 0); // total deposited is 0 at this point
            assertEq(
                multiplier, expectedMultiplier, "twTap_participate::test_WhenItShouldParticipate: Invalid multiplier"
            );
        }

        // it should update weekTotals
        uint256 vote = _lockAmount * expectedMultiplier;
        int256 netActiveVotesFirstWeek = twTap.weekTotals(1);
        int256 netActiveVotesLastWeek = twTap.weekTotals(_timestampToWeek(expiry) + 1);
        assertEq(
            netActiveVotesFirstWeek,
            int256(vote),
            "twTap_participate::test_WhenItShouldParticipate: Invalid netActiveVotes"
        );
        assertEq(
            netActiveVotesLastWeek,
            -int256(vote),
            "twTap_participate::test_WhenItShouldParticipate: Invalid netActiveVotes"
        );

        // it should mint a twTAP token
        assertEq(
            twTap.ownerOf(TWTAP_TOKEN_ID), aliceAddr, "twTap_participate::test_WhenItShouldParticipate: Invalid owner"
        );
    }

    function _timestampToWeek(uint256 _timestamp) internal view returns (uint256) {
        return (_timestamp - twTap.creation()) / twTap.EPOCH_DURATION();
    }
}
