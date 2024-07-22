// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";

contract twTap_participate is twTapBaseTest {
    function test_RevertWhen_LockNotAWeekLong() external {
        // it should revert
        vm.expectRevert(TwTAP.LockNotAWeek.selector);
        twTap.participate(aliceAddr, 100, 100);
    }

    function test_RevertWhen_LockTooLong() external {
        // it should revert
        uint256 duration = twTap.MAX_LOCK_DURATION();
        vm.expectRevert(TwTAP.LockTooLong.selector);
        twTap.participate(aliceAddr, 100, duration + 1);
    }

    function test_RevertWhen_DurationNotAMultipleOfEpochDuration() external {
        // it should revert
        uint256 duration = twTap.EPOCH_DURATION();
        vm.expectRevert(TwTAP.DurationNotMultiple.selector);
        twTap.participate(aliceAddr, 100, duration + 1);
    }

    function test_RevertWhen_WeekNotAdvanced() external skipWeeks(1) {
        // it should revert
        uint256 duration = twTap.EPOCH_DURATION();
        vm.expectRevert(TwTAP.AdvanceWeekFirst.selector);
        twTap.participate(aliceAddr, 100, duration);
    }

    function test_ShouldParticipate() external {
        // it should participate
        vm.startPrank(aliceAddr);
        uint256 duration = twTap.EPOCH_DURATION();
        uint256 snapshot = vm.snapshot();

        _shouldParticipate(duration, 100, false);
        vm.revertTo(snapshot);

        duration = twTap.EPOCH_DURATION() * 2;
        uint256 amountForVotingPower = (twTap.VIRTUAL_TOTAL_AMOUNT() * twTap.MIN_WEIGHT_FACTOR()) / 1e4;
        _shouldParticipate(duration, amountForVotingPower, true);
    }

    function _shouldParticipate(uint256 _duration, uint256 _amount, bool _hasVotingPower) internal {
        tapOFT.freeMint(aliceAddr, _amount);

        tapOFT.approve(address(pearlmit), _amount);
        pearlmit.approve(20, address(tapOFT), 0, address(twTap), uint200(_amount), uint48(block.timestamp + 1));

        vm.expectEmit(true, true, true, false);
        emit TwTAP.Participate(aliceAddr, 1, _amount, 0, _duration);
        twTap.participate(aliceAddr, _amount, _duration);
        assertEq(twTap.ownerOf(1), aliceAddr, "twTap_participate::test_ShouldParticipate: Invalid owner");

        if (_hasVotingPower) {
            (uint256 totalParticipants,, uint256 totalDeposited,) = twTap.twAML();
            assertEq(totalParticipants, 1, "twTap_participate::test_ShouldParticipate: Invalid totalParticipants");
            assertEq(totalDeposited, _amount, "twTap_participate::test_ShouldParticipate: Invalid totalDeposited");
        }
    }
}
