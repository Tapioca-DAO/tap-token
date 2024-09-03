// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TWAML} from "contracts/options/twAML.sol";

import "forge-std/Test.sol";

contract twl_CapCumulativeReward is TWAML, Test {
    uint256 constant TOB_MULTIPLIER = 5 * 1e4;
    uint256 constant TOB_CAP = 2 * 1e4;
    uint256 constant MIN_TOB_AMOUNT = 1e4;
    uint256 constant MAX_TOB_AMOUNT = 50 * 1e4;

    uint256 constant TWTAP_MULTIPLIER = 10 * 1e4;
    uint256 constant TWTAP_CAP = 5 * 1e4;
    uint256 constant MIN_TWTAP_AMOUNT = 1e4;
    uint256 constant MAX_TWTAP_AMOUNT = 100 * 1e4;

    /**
     * @dev It should cap the cumulative reward to the nearest multiplier of 5.
     */
    function test_shouldCapCumulativeRewardOnTob(uint256 _amount) external {
        _amount = bound(_amount, MIN_TOB_AMOUNT, MAX_TOB_AMOUNT);

        // it should cap the cumulative reward
        assertEq(
            capCumulativeReward(_amount, TOB_MULTIPLIER, TOB_CAP) % TOB_MULTIPLIER,
            0,
            "twl_CapCumulativeReward::test_shouldCapCumulativeRewardOnTob: Invalid amount"
        );
    }

    /**
     * @dev It should cap the cumulative reward to the nearest multiplier of 10.
     */
    function test_shouldCapCumulativeRewardOnTwTap(uint256 _amount) external {
        _amount = bound(_amount, MIN_TWTAP_AMOUNT, MAX_TWTAP_AMOUNT);

        // it should cap the cumulative reward
        assertEq(
            capCumulativeReward(_amount, TWTAP_MULTIPLIER, TWTAP_CAP) % TWTAP_MULTIPLIER,
            0,
            "twl_CapCumulativeReward::test_shouldCapCumulativeRewardOnTwTap: Invalid amount"
        );
    }
}
