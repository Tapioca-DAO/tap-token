// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract TOB_newEpoch is TobBaseTest {
    function test_RevertWhen_NotAuthorized() external {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.newEpoch();
    }

    function test_RevertWhen_TooSoon() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);
        cluster.setRoleForContract(adminAddr, keccak256("NEW_EPOCH"), true);
        tob.init();

        vm.expectRevert(TapiocaOptionBroker.TooSoon.selector);
        tob.newEpoch();
    }

    function test_RevertWhen_NoActiveSingularities() external {
        // it should revert
        vm.startPrank(adminAddr);
        cluster.setRoleForContract(adminAddr, keccak256("NEW_EPOCH"), true);

        skip(tob.EPOCH_DURATION());
        vm.expectRevert(TapiocaOptionBroker.NoActiveSingularities.selector);
        tob.newEpoch();
    }

    function test_ShouldAdvanceTheEpoch() external registerSingularityPool {
        // it should advance the epoch
        vm.startPrank(adminAddr);
        cluster.setRoleForContract(adminAddr, keccak256("NEW_EPOCH"), true);
        tob.init();
        skip(tob.EPOCH_DURATION());

        vm.expectEmit(true, false, false, false);
        emit TapiocaOptionBroker.NewEpoch(1, 0, 0);
        tob.newEpoch();
        assertEq(tob.epoch(), 1, "TOB_newEpoch::test_ShouldAdvanceTheEpoch: Invalid epoch");
    }
}
