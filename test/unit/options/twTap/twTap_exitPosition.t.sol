// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";
import {TWAML} from "contracts/options/twAML.sol";

contract twTap_exitPosition is twTapBaseTest, TWAML {
    uint256 constant TWTAP_TOKEN_ID = 1;
    uint256 LOCK_TIME;

    function setUp() public virtual override {
        super.setUp();
        LOCK_TIME = twTap.EPOCH_DURATION() * 4;
    }

    function test_RevertWhen_Paused() external {
        vm.prank(adminAddr);
        twTap.setPause(true);
        // it should revert
        vm.expectRevert("Pausable: paused");
        twTap.exitPosition(TWTAP_TOKEN_ID);
    }

    modifier whenNotPaused() {
        _;
    }

    modifier whenLockNotExpired() {
        _;
    }

    modifier whenParticipating(uint256 _lockAmount, uint256 _lockDuration) {
        (_lockAmount, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _participate(_lockAmount, _lockDuration);
        _;
    }

    function test_RevertWhen_NotInRescueMode(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenLockNotExpired
        whenParticipating(_lockAmount, _lockDuration)
    {
        // it should revert
        vm.expectRevert(TwTAP.LockNotExpired.selector);
        twTap.exitPosition(TWTAP_TOKEN_ID);
    }

    function test_WhenInRescueMode(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenLockNotExpired
        whenParticipating(_lockAmount, _lockDuration)
    {
        vm.prank(adminAddr);
        twTap.setRescueMode(true);
        // it should continue
        twTap.exitPosition(TWTAP_TOKEN_ID);
    }

    modifier whenLockExpired(uint256 _lockDuration) {
        _whenLockExpired(_lockDuration);
        _;
    }

    function _whenLockExpired(uint256 _lockDuration) internal {
        (, _lockDuration) = _boundValues(0, _lockDuration);
        skip(_lockDuration * twTap.EPOCH_DURATION());
        vm.prank(adminAddr);
        twTap.advanceWeek(_lockDuration);
    }

    function test_WhenTapReleased(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenParticipating(_lockAmount, _lockDuration)
        whenLockExpired(_lockDuration)
    {
        // it should stop execution and return 0
        twTap.exitPosition(TWTAP_TOKEN_ID);
        assertEq(twTap.exitPosition(TWTAP_TOKEN_ID), 0, "twTap_exitPosition::test_WhenTapReleased: Invalid tapReleased");
    }

    modifier whenTapWasNotReleased() {
        _;
    }

    function _whenParticipatingWithNoVotingPower(uint256 _lockAmount, uint256 _lockDuration)
        internal
        returns (uint256, uint256)
    {
        (, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        // Less than the minimum weight
        _lockAmount =
            bound(_lockAmount, 1, computeMinWeight(twTap.VIRTUAL_TOTAL_AMOUNT(), twTap.MIN_WEIGHT_FACTOR()) - 1);
        _participate(_lockAmount, _lockDuration);
        return (_lockAmount, _lockDuration);
    }

    function test_WhenUserHasNoVotingPower(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenTapWasNotReleased
    {
        (_lockAmount, _lockDuration) = _whenParticipatingWithNoVotingPower(_lockAmount, _lockDuration);
        _whenLockExpired(_lockDuration);

        (
            uint256 totalParticipantsBef,
            uint256 averageMagnitudeBef,
            uint256 totalDepositedBef,
            uint256 cumulativeBeforeBef
        ) = twTap.twAML();
        // it should continue
        test_WhenItShouldContinue(_lockAmount, _lockDuration);

        // it should not change AML
        (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulativeBefore) =
            twTap.twAML();
        assertEq(
            totalParticipants,
            totalParticipantsBef,
            "twTap_exitPosition::test_WhenUserHasNoVotingPower: Invalid totalParticipants"
        );
        assertEq(
            averageMagnitude,
            averageMagnitudeBef,
            "twTap_exitPosition::test_WhenUserHasNoVotingPower: Invalid averageMagnitude"
        );
        assertEq(
            totalDeposited,
            totalDepositedBef,
            "twTap_exitPosition::test_WhenUserHasNoVotingPower: Invalid totalDeposited"
        );
        assertEq(
            cumulativeBefore,
            cumulativeBeforeBef,
            "twTap_exitPosition::test_WhenUserHasNoVotingPower: Invalid cumulativeBefore"
        );
    }

    function test_WhenUserHasVotingPower(uint256 _lockAmount, uint256 _lockDuration)
        external
        whenNotPaused
        whenTapWasNotReleased
        whenParticipating(_lockAmount, _lockDuration)
        whenLockExpired(_lockDuration)
    {
        (uint256 _lockAmount, uint256 _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        // it should continue
        test_WhenItShouldContinue(_lockAmount, _lockDuration);

        // it should update the AML with the inverse recorded
        (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative) =
            twTap.twAML();
        assertEq(totalParticipants, 0, "twTap_exitPosition::test_WhenUserHasVotingPower: Invalid totalParticipants");
        assertEq(totalDeposited, 0, "twTap_exitPosition::test_WhenUserHasVotingPower: Invalid totalDeposited");
        assertEq(cumulative, LOCK_TIME, "twTap_exitPosition::test_WhenUserHasVotingPower: Invalid cumulative");
    }

    function test_WhenItShouldContinue(uint256 _lockAmount, uint256 _lockDuration) internal {
        // it should emit ExitPosition
        vm.expectEmit(true, true, true, true);
        emit TwTAP.ExitPosition(TWTAP_TOKEN_ID, aliceAddr, _lockAmount);
        twTap.exitPosition(TWTAP_TOKEN_ID);

        // it should mark the participant tap as released
        (,,, bool tapReleased,,,,,,) = twTap.participants(TWTAP_TOKEN_ID);
        assertEq(tapReleased, true, "twTap_exitPosition::test_WhenItShouldContinue: Invalid tapReleased");

        // it should transfer the Tap tokens to the owner of the lock
        assertEq(
            tapOFT.balanceOf(aliceAddr), _lockAmount, "twTap_exitPosition::test_WhenItShouldContinue: Invalid balance"
        );
    }

    function _boundValues(uint256 _lockAmount, uint256 _lockDuration) internal pure returns (uint256, uint256) {
        _lockAmount = bound(_lockAmount, 1, type(uint88).max);
        _lockDuration = bound(_lockDuration, 1, 4);
        return (_lockAmount, _lockDuration);
    }
}
