// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, IERC20} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract getSingularityPoolInfo is TobBaseTest {
    function test_ShouldReturnTheRightValues() external setupAndParticipate(aliceAddr, 100, 0) {
        // it should return the right values
        (uint256 assetId, uint256 totalDeposited, uint256 weight, bool isInRescue,,) =
            tob.getSingularityPoolInfo(IERC20(address(0x1)), 1);
        assertEq(assetId, 1, "TOB_getSingularityPoolInfo: Invalid assetId");
        assertEq(totalDeposited, 100, "TOB_getSingularityPoolInfo: Invalid totalDeposited");
        assertEq(weight, 1, "TOB_getSingularityPoolInfo: Invalid weight");
        assertEq(isInRescue, false, "TOB_getSingularityPoolInfo: Invalid isInRescue");
    }
}
