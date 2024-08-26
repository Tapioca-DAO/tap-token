// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";
import {WeekTotals, Participation} from "contracts/governance/twTAP.sol";

contract twTap_advanceWeek is twTapBaseTest {
    uint256 constant PARTICIPATION_ID = 1;

    modifier whenParticipating(address _to, uint256 _lockAmount, uint256 _lockDuration) {
        (_lockAmount, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _participate(_to, _lockAmount, _lockDuration);
        _;
    }

    function test_RevertWhen_CallerDoesNotHaveRole() external {
        // it should revert
        vm.expectRevert(TwTAP.NotAuthorized.selector);
        twTap.advanceWeek(1);
    }

    modifier whenCallerHasRole() {
        _;
        _resetPrank(adminAddr);
        cluster.setRoleForContract(adminAddr, keccak256("NEW_EPOCH"), true);
    }

    function test_WhenTimeDidNotAdvanceEnoughToAdvanceWeek() external whenCallerHasRole {
        // it should do nothing
        vm.startPrank(adminAddr);
        twTap.advanceWeek(1);

        assertEq(
            twTap.lastProcessedWeek(),
            0,
            "twTap_advanceWeek::test_WhenTimeDidNotAdvanceEnoughToAdvanceWeek: Invalid epoch"
        );
    }

    modifier whenTimeAdvancedEnough() {
        skip(twTap.EPOCH_DURATION());
        _;
    }

    function test_WhenTimeAdvancedEnough(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenParticipating(aliceAddr, _lockAmount, _lockDuration)
        whenCallerHasRole
        whenTimeAdvancedEnough
    {
        _resetPrank(adminAddr);

        // it should emit AdvanceEpoch
        vm.expectEmit(true, true, false, false);
        emit TwTAP.AdvanceEpoch(1, 0);
        twTap.advanceWeek(1);

        // it should pass week net active votes
        int256 netActiveVotesBef = twTap.weekTotals(0);
        int256 netActiveVotesAft = twTap.weekTotals(1);
        assertGt(
            netActiveVotesAft,
            netActiveVotesBef,
            "twTap_advanceWeek::test_WhenTimeAdvancedEnough: Invalid week net active votes"
        );

        // it should update lastProcessedWeek
        assertEq(twTap.lastProcessedWeek(), 1, "twTap_advanceWeek::test_WhenTimeAdvancedEnough: Invalid epoch");
    }

    function test_WhenDecayRateIsNotSet(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenParticipating(aliceAddr, _lockAmount, _lockDuration)
        whenCallerHasRole
        whenTimeAdvancedEnough
    {
        _resetPrank(adminAddr);

        // it should do nothing
        (,,, uint256 cumulativeBef) = twTap.twAML();
        twTap.advanceWeek(1);
        (,,, uint256 cumulativeAft) = twTap.twAML();
        assertEq(cumulativeAft, cumulativeBef, "twTap_advanceWeek::test_WhenDecayRateIsNotSet: Invalid cumulative");
    }

    modifier whenDecayRateIsBiggerThan0() {
        _resetPrank(adminAddr);
        twTap.setDecayRateBps(1000);
        _;
    }

    function test_RevertWhen_EpochSmallerThan2(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenParticipating(aliceAddr, _lockAmount, _lockDuration)
        whenCallerHasRole
        whenTimeAdvancedEnough
        whenDecayRateIsBiggerThan0
    {
        // it should revert
        _resetPrank(adminAddr);
        vm.expectRevert(TwTAP.EpochTooLow.selector);
        twTap.advanceWeek(1);
    }

    /// @notice We already skipped one epoch in `whenTimeAdvancedEnough()`
    modifier whenEpochBiggerOrEqual2(uint256 _lockDuration) {
        uint256 unlockEpoch = _getUnlockEpoch();
        skip(twTap.EPOCH_DURATION() * (unlockEpoch - 1));
        _;
    }

    modifier whenLiquidityDecreased() {
        twTap.exitPosition(1); // First we need to exit the position to decrease the liquidity
        _;
    }

    function test_WhenLiquidityDecreasedMoreThanTheDecayActivation(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenParticipating(aliceAddr, _lockAmount, _lockDuration)
        whenCallerHasRole
        whenTimeAdvancedEnough
        whenEpochBiggerOrEqual2(_lockDuration)
        whenDecayRateIsBiggerThan0
        whenLiquidityDecreased
    {
        _resetPrank(adminAddr);

        (,,, uint256 cumulativeBef) = twTap.twAML();
        // We need to skip the decay activation
        skip(twTap.EPOCH_DURATION());
        twTap.advanceWeek(_getUnlockEpoch());
        (,,, uint256 cumulativeAft) = twTap.twAML();

        // it should decay
        assertGt(
            cumulativeBef,
            cumulativeAft,
            "twTap_advanceWeek::test_WhenLiquidityDecreasedMoreThanTheDecayActivation: Invalid cumulative"
        );
    }

    function test_WhenLiquidityDidNotDecreasedMoreThanHeDecayActivation(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenParticipating(aliceAddr, 1, _lockDuration)
        whenCallerHasRole
        whenTimeAdvancedEnough
        whenDecayRateIsBiggerThan0
        whenEpochBiggerOrEqual2(_lockDuration)
        whenLiquidityDecreased
    {
        // it should not decay

        (,,, uint256 cumulativeBef) = twTap.twAML();
        skip(twTap.EPOCH_DURATION());
        twTap.advanceWeek(_getUnlockEpoch());
        (,,, uint256 cumulativeAft) = twTap.twAML();

        // it should decay
        Participation memory participation = twTap.getParticipation(PARTICIPATION_ID);
        assertEq(
            cumulativeBef,
            cumulativeBef - participation.averageMagnitude,
            "twTap_advanceWeek::test_WhenLiquidityDidNotDecreasedMoreThanHeDecayActivation: Invalid cumulative"
        );
    }

    function test_WhenLiquidityDidNotDecrease(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenParticipating(aliceAddr, _lockAmount, _lockDuration)
        whenCallerHasRole
        whenTimeAdvancedEnough
        whenDecayRateIsBiggerThan0
        whenEpochBiggerOrEqual2(_lockDuration)
    {
        // it should not decay
        _resetPrank(adminAddr);

        (,,, uint256 cumulativeBef) = twTap.twAML();
        // We need to skip the decay activation
        skip(twTap.EPOCH_DURATION());
        twTap.advanceWeek(1);
        (,,, uint256 cumulativeAft) = twTap.twAML();

        // it should decay
        assertEq(
            cumulativeBef, cumulativeAft, "twTap_advanceWeek::test_WhenLiquidityDidNotDecrease: Invalid cumulative"
        );
    }

    function _getUnlockEpoch() internal returns (uint256) {
        Participation memory participation = twTap.getParticipation(PARTICIPATION_ID);
        return _toWeek(participation.expiry);
    }
}
