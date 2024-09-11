// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, IERC20} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract getSingularityPoolInfo is TobBaseTest {
    function test_ShouldReturnTheRightValues(uint128 _lockAmount, uint128 _lockDuration) external {
        (_lockAmount, _lockDuration) = _boundValues(_lockAmount, _lockDuration);
        _setupAndParticipate(aliceAddr, _lockAmount, _lockDuration);

        // it should return the right values
        (uint256 assetId, uint256 totalDeposited, uint256 weight, bool isInRescue,,,,) =
            tob.getSingularityPoolInfo(IERC20(address(toftSglEthMarket)), 1);
        assertEq(assetId, ybAssetIdToftSglEthMarket, "TOB_getSingularityPoolInfo: Invalid assetId");
        assertEq(totalDeposited, _lockAmount, "TOB_getSingularityPoolInfo: Invalid totalDeposited");
        assertEq(weight, 1, "TOB_getSingularityPoolInfo: Invalid weight");
        assertEq(isInRescue, false, "TOB_getSingularityPoolInfo: Invalid isInRescue");
    }
}
