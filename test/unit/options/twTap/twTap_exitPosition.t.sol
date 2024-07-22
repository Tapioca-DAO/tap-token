// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";

contract twTap_exitPosition is twTapBaseTest {
    function test_RevertWhen_Paused() external {
        // it should revert
        vm.prank(adminAddr);
        twTap.setPause(true);

        vm.expectRevert("Pausable: paused");
        twTap.exitPosition(1);
    }

    modifier whenLockNotExpired() {
        _;
    }

    function test_RevertWhen_NotInRescueMode() external whenLockNotExpired participate(100, 1) {
        // it should revert
        vm.expectRevert(TwTAP.LockNotExpired.selector);
        twTap.exitPosition(1);
    }

    function test_WhenTapAlreadyReleased() external participate(100, 1) skipWeeks(1) advanceWeeks(1) {
        // it should return 0
        {
            uint256 releasedAmount = twTap.exitPosition(1);
            assertGt(releasedAmount, 0, "twTap_exitPosition::test_WhenTapAlreadyReleased: Invalid releasedAmount");
        }
        {
            uint256 releasedAmount = twTap.exitPosition(1);
            assertEq(releasedAmount, 0, "twTap_exitPosition::test_WhenTapAlreadyReleased: Invalid releasedAmount");
        }
    }

    function test_ShouldExitThePosition()
        external
        participate(100, 1)
        participate(1e24, 1)
        skipWeeks(1)
        advanceWeeks(1)
    {
        // it should exit the position
        _shouldExit(1, 100, false);
        _shouldExit(2, 1e24, true);
    }

    function _shouldExit(uint256 _tokenId, uint256 _amount, bool _hasVotingPower) internal {
        vm.expectEmit(true, true, false, false);
        emit TwTAP.ExitPosition(_tokenId, aliceAddr, 0);
        uint256 releasedAmount = twTap.exitPosition(_tokenId);

        assertGt(releasedAmount, 0, "twTap_exitPosition::test_ShouldExitThePosition: Invalid releasedAmount");
        assertApproxEqAbs(
            tapOFT.balanceOf(aliceAddr), _amount, 100, "twTap_exitPosition::test_ShouldExitThePosition: Invalid balance"
        );

        if (_hasVotingPower) {
            (uint256 totalParticipants,, uint256 totalDeposited,) = twTap.twAML();
            assertEq(totalParticipants, 0, "twTap_participate::test_ShouldParticipate: Invalid totalParticipants");
            assertEq(totalDeposited, 0, "twTap_participate::test_ShouldParticipate: Invalid totalDeposited");
        }
    }
}
