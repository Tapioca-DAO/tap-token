// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.t.sol";

contract TOB_getCurrentWeek is TobBaseTest {
    function test_ShouldReturnTheRightTimestampToWeek() external tobInit {
        // it should return the right timestamp to week
        assertEq(tob.getCurrentWeek(), 0, "TOB_getCurrentWeek: test_ShouldReturnTheRightTimestampToWeek");
        vm.warp(block.timestamp + 1 weeks);
        assertEq(tob.getCurrentWeek(), 1, "TOB_getCurrentWeek: test_ShouldReturnTheRightTimestampToWeek");
    }
}
