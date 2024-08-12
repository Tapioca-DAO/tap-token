// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker, ITapiocaOracle} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract TOB_newEpoch is TobBaseTest {
    function test_RevertWhen_NotAuthorized() external {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.newEpoch();
    }

    modifier whenAuthorized() {
        vm.startPrank(adminAddr);
        cluster.setRoleForContract(adminAddr, keccak256("NEW_EPOCH"), true);
        _;
    }

    function test_RevertWhen_EpochNotOver() external whenAuthorized {
        vm.warp(0);
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TooSoon.selector);
        tob.newEpoch();
    }

    modifier whenEpochIsOver() {
        skip(tob.EPOCH_DURATION());
        _;
    }

    function test_RevertWhen_NotActiveSingularities() external whenAuthorized whenEpochIsOver {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.NoActiveSingularities.selector);
        tob.newEpoch();
    }

    modifier whenActiveSingularitiesExist() {
        _registerSingularityPool();
        _;
    }

    function test_RevertWhen_TapOracleFailsToQuery()
        external
        tobInit
        whenEpochIsOver
        whenActiveSingularitiesExist
        whenAuthorized
    {
        tob.setTapOracle(ITapiocaOracle(address(failingOracleMock)), "0x");
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.Failed.selector);
        tob.newEpoch();
    }

    function test_WhenTapOracleQueryWorks()
        external
        tobInit
        whenEpochIsOver
        whenActiveSingularitiesExist
        whenAuthorized
    {
        // it should emit new epoch event
        vm.expectEmit(true, false, false, false);
        emit TapiocaOptionBroker.NewEpoch(1, 0, 0);
        tob.newEpoch();
        // it should increment `epoch` by 1
        assertEq(tob.epoch(), 1, "TOB_newEpoch::test_ShouldAdvanceTheEpoch: Invalid epoch");
        // it should extract and emit tap to gauges
    }
}
