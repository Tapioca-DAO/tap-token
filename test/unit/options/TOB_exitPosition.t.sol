// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker, IERC20} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract TOB_exitPosition is TobBaseTest {
    function test_RevertWhen_PositionNotExisting() external {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.PositionNotValid.selector);
        tob.exitPosition(1);
    }

    modifier whenLockExpired() {
        skip(tob.EPOCH_DURATION() * 2);
        _;
    }

    function test_WhenSglInRescue()
        external
        whenLockExpired
        setupAndParticipate(aliceAddr, 100, 0)
        setSglInRescue(IERC20(address(0x1)), 1)
    {
        // it should not revert
        tob.exitPosition(1);
    }

    function test_RevertWhen_SglNotInRescue() external whenLockExpired setupAndParticipate(aliceAddr, 100, 0) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.LockNotExpired.selector);
        tob.exitPosition(1);
    }

    function test_ShouldExitThePosition() external setupAndParticipate(aliceAddr, 100, 0) skipEpochs(1) {
        // it should exit the position

        vm.expectEmit(true, true, true, false);
        emit TapiocaOptionBroker.ExitPosition(1, 1, 1);
        tob.exitPosition(1);

        (,, uint256 userAverageMagnitude) = tob.participants(1);
        assertEq(userAverageMagnitude, 0, "TOB_exitPosition::test_ShouldExitThePosition: Invalid userAverageMagnitude");

        (uint256 totalParticipantsAfter,,,) = tob.twAML(1);
        assertEq(totalParticipantsAfter, 0, "TOB_exitPosition::test_ShouldExitThePosition: Invalid totalParticipants");
        (,, uint256 totalDepositedAfter,) = tob.twAML(1);
        assertEq(totalDepositedAfter, 0, "TOB_exitPosition::test_ShouldExitThePosition: Invalid totalDeposited");
        (,,, uint256 cumulativeAfter) = tob.twAML(1);
        assertEq(cumulativeAfter, 0, "TOB_exitPosition::test_ShouldExitThePosition: Invalid cumulative");

        vm.expectRevert("ERC721: invalid token ID");
        otap.ownerOf(1);
    }
}
