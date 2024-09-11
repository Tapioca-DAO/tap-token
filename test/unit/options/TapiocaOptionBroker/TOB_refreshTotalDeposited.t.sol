// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract TOB_refreshTotalDeposited is TobBaseTest {
    uint256 constant PARTICIPATE_AMOUNT = 1e18;

    function test_WhenParamArrayIsEmpty() external {
        // it should do nothing
        uint256[] memory emptyArray;
        uint256[] memory returnArray = tob.refreshTotalDeposited(emptyArray);
        assertEq(
            returnArray.length, 0, "TOB_refreshTotalDeposited::test_WhenParamArrayIsEmpty: Invalid returnArray length"
        );
        assertEq(
            tob.lastTotalDepositedForSgl(ybAssetIdToftSglEthMarket),
            0,
            "TOB_refreshTotalDeposited::test_WhenParamArrayIsEmpty: Invalid lastTotalDepositedForSgl"
        );
        assertEq(
            tob.lastTotalDepositRefreshSgl(ybAssetIdToftSglEthMarket),
            0,
            "TOB_refreshTotalDeposited::test_WhenParamArrayIsEmpty: Invalid lastTotalDepositRefreshSgl"
        );
    }

    modifier whenParamArrayIsSet() {
        _setupAndParticipate(aliceAddr, PARTICIPATE_AMOUNT, uint128(tob.EPOCH_DURATION()));
        _;
    }

    function test_WhenRefreshCooldownIsNotMet() external whenParamArrayIsSet {
        // it should return the previously set value
        uint256[] memory sglArray = new uint256[](1);
        sglArray[0] = ybAssetIdToftSglEthMarket;
        uint256[] memory returnArray = tob.refreshTotalDeposited(sglArray);
        assertEq(
            returnArray.length,
            1,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsNotMet: Invalid returnArray length"
        );
        assertEq(
            tob.lastTotalDepositedForSgl(ybAssetIdToftSglEthMarket),
            PARTICIPATE_AMOUNT,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsNotMet: Invalid lastTotalDepositedForSgl"
        );
        assertEq(
            tob.lastTotalDepositRefreshSgl(ybAssetIdToftSglEthMarket),
            block.timestamp,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsNotMet: Invalid lastTotalDepositRefreshSgl"
        );
    }

    function test_WhenRefreshCooldownIsMet() external whenParamArrayIsSet {
        // Setup previous value
        uint256[] memory sglArray = new uint256[](1);
        sglArray[0] = ybAssetIdToftSglEthMarket;
        uint256[] memory returnArray = tob.refreshTotalDeposited(sglArray);
        assertEq(
            tob.lastTotalDepositedForSgl(ybAssetIdToftSglEthMarket),
            PARTICIPATE_AMOUNT,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDepositedForSgl"
        );
        assertEq(
            tob.lastTotalDepositRefreshSgl(ybAssetIdToftSglEthMarket),
            block.timestamp,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDepositRefreshSgl"
        );

        // Update values to new value
        skip(tob.EPOCH_DURATION() / 2); // Arbitrary value to simulate time passing
        _tobParticipate(bobAddr, uint200(PARTICIPATE_AMOUNT), uint128(tob.EPOCH_DURATION()), 2);
        sglArray[0] = ybAssetIdToftSglEthMarket;
        returnArray = tob.refreshTotalDeposited(sglArray);

        // it should update lastTotalDepositedForSgl with the newly fetch value
        assertEq(
            tob.lastTotalDepositedForSgl(ybAssetIdToftSglEthMarket),
            PARTICIPATE_AMOUNT * 2,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDepositedForSgl"
        );

        // it should update lastTotalDepositRefreshSgl to block.timestamp
        assertEq(
            tob.lastTotalDepositRefreshSgl(ybAssetIdToftSglEthMarket),
            block.timestamp,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDepositRefreshSgl"
        );

        // it should return the new value of lastTotalDepositedForSgl
        assertEq(
            returnArray[0],
            PARTICIPATE_AMOUNT * 2,
            "TOB_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid returnArray"
        );
    }
}
