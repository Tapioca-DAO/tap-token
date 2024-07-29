// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract TOB_exitPosition is TobBaseTest {
    function test_RevertWhen_OtapNotExisting() external {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.PositionNotValid.selector);
        tob.exitPosition(1);
    }

    function test_WhenSglIsInRescue() external setupAndParticipate(aliceAddr, 100, 1) skipEpochs(2) setPoolRescue {
        // it should not revert
        tob.exitPosition(1);
    }

    modifier whenSglIsNotInRescue() {
        _;
    }

    function test_RevertWhen_LockIsNotExpired() external whenSglIsNotInRescue setupAndParticipate(aliceAddr, 100, 1) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.LockNotExpired.selector);
        tob.exitPosition(1);
    }

    function test_ShouldExitThePosition() external setupAndParticipate(aliceAddr, 100, 1) skipEpochs(2) {
        // it should exit the position
        vm.expectEmit(true, true, true, false);
        emit TapiocaOptionBroker.ExitPosition(2, 1, 1);
        tob.exitPosition(1);

        (uint256 totalParticipants,, uint256 totalDeposited, uint256 cumulative) = tob.twAML(1);
        assertEq(totalParticipants, 0, "TOB_exitPosition::test_ShouldExitThePosition: Invalid totalParticipants");
        assertEq(totalDeposited, 0, "TOB_exitPosition::test_ShouldExitThePosition: Invalid totalDeposited");
        assertEq(cumulative, 0, "TOB_exitPosition::test_ShouldExitThePosition: Invalid cumulative");

        assertEq(tolp.ownerOf(1), aliceAddr, "TOB_exitPosition::test_ShouldExitThePosition: Invalid owner");
    }
}
