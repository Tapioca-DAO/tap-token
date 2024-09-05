// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest} from "test/unit/options/twTap/twTapBaseTest.sol";

contract twTap_refreshTotalDeposited is twTapBaseTest {
    uint256 public PARTICIPATE_AMOUNT;
    uint256 constant PARTICIPATE_WEEKS = 4;

    function setUp() public virtual override {
        super.setUp();
        PARTICIPATE_AMOUNT = twTap.VIRTUAL_TOTAL_AMOUNT();
    }

    modifier whenParamArrayIsSet() {
        _participateUser(aliceAddr);
        _;
    }

    function _participateUser(address _user) internal {
        (uint256 _lockAmount, uint256 _lockDuration) = _boundValues(PARTICIPATE_AMOUNT, PARTICIPATE_WEEKS);
        _participate(_user, _lockAmount, _lockDuration);
    }

    function test_WhenRefreshCooldownIsNotMet() external whenParamArrayIsSet {
        skip(twTap.refreshCooldown() + 1);
        // it should return the previously set value
        uint256 returnVal = twTap.refreshTotalDeposited();

        assertEq(
            twTap.lastTotalDeposited(),
            PARTICIPATE_AMOUNT,
            "twTap_refreshTotalDeposited::test_WhenRefreshCooldownIsNotMet: Invalid lastTotalDeposited"
        );
        assertEq(
            twTap.lastTotalDepositRefresh(),
            block.timestamp,
            "twTap_refreshTotalDeposited::test_WhenRefreshCooldownIsNotMet: Invalid lastTotalDepositRefresh"
        );
    }

    function test_WhenRefreshCooldownIsMet() external whenParamArrayIsSet {
        skip(twTap.refreshCooldown());

        // Setup previous value
        uint256 returnVal = twTap.refreshTotalDeposited();
        assertEq(
            twTap.lastTotalDeposited(),
            PARTICIPATE_AMOUNT,
            "twTap_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDeposited"
        );
        assertEq(
            twTap.lastTotalDepositRefresh(),
            block.timestamp,
            "twTap_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDepositRefresh"
        );

        // Update values to new value
        skip(twTap.EPOCH_DURATION() / 2); // Arbitrary value to simulate time passing
        _participateUser(bobAddr);
        skip(twTap.refreshCooldown());
        returnVal = twTap.refreshTotalDeposited();

        // it should update lastTotalDeposited with the newly fetch value
        assertEq(
            twTap.lastTotalDeposited(),
            PARTICIPATE_AMOUNT * 2,
            "twTap_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDeposited"
        );

        // it should update lastTotalDepositRefresh to block.timestamp
        assertEq(
            twTap.lastTotalDepositRefresh(),
            block.timestamp,
            "twTap_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid lastTotalDepositRefresh"
        );

        // it should return the new value of lastTotalDeposited
        assertEq(
            returnVal,
            PARTICIPATE_AMOUNT * 2,
            "twTap_refreshTotalDeposited::test_WhenRefreshCooldownIsMet: Invalid returnVal"
        );
    }
}
