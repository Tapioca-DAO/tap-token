// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, SingularityPool} from "./TolpBaseTest.sol";

contract TOLP_getSingularityPools is TolpBaseTest {
    function test_ShouldReturnTheRightArrayOfPools() external registerSingularityPool {
        // it should return the right array of pools
        SingularityPool[] memory pools = tolp.getSingularityPools();

        assertEq(pools.length, 5, "TOLP_getSingularityPools: Invalid pools length");
    }

    function test_WhenThereIsAPoolInRescue() external registerSingularityPool setPoolRescue {
        // it should return the array without the rescue pool
        SingularityPool[] memory pools = tolp.getSingularityPools();
        assertEq(pools[0].sglAssetID, 0, "TOLP_getSingularityPools: Invalid pools length in rescue mode");
    }
}
