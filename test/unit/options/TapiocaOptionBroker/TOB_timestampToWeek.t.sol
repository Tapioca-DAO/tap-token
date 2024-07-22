// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract TOB_timestampToWeek is TobBaseTest {
    function test_WhenTimestampIs0() external tobInit {
        // it should return 0
        assertEq(tob.timestampToWeek(block.timestamp), 0, "TOB_timestampToWeek: test_WhenTimestampIs0");
    }

    function test_WhenTimestampIsLessThanEmissionStartTime() external tobInit {
        // it should return 0
        assertEq(
            tob.timestampToWeek(block.timestamp - 1 weeks),
            0,
            "TOB_timestampToWeek: test_WhenTimestampIsLessThanEmissionStartTime"
        );
    }

    function test_ShouldReturnTheRightTimestampToWeek() external tobInit {
        // it should return the right timestamp to week
        assertEq(
            tob.timestampToWeek(block.timestamp + 1 weeks),
            1,
            "TOB_timestampToWeek: test_ShouldReturnTheRightTimestampToWeek"
        );
    }
}
