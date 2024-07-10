// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.t.sol";
import {LockPosition} from "contracts/options/TapiocaOptionLiquidityProvision.sol";
import {TapOption} from "contracts/options/oTAP.sol";

contract TOB_getOptionPosition is TobBaseTest {
    function test_ShouldReturnTheRightOptionPosition() external tobInit tobParticipate {
        // it should return the right option position
        (LockPosition memory tOLPLockPosition, TapOption memory oTAPPosition, uint256 claimedTapInEpoch) =
            tob.getOptionPosition(1, 0);
        assertEq(tOLPLockPosition.sglAssetID, 1, "TOB_getOptionPosition: Invalid sglAssetID");
        assertEq(oTAPPosition.tOLP, 1, "TOB_getOptionPosition: Invalid tOLP");
    }
}