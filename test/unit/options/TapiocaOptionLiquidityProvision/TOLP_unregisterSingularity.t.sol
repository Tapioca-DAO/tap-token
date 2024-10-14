// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20} from "./TolpBaseTest.sol";

contract TOLP_unregisterSingularity is TolpBaseTest {
    function test_RevertWhen_NotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        tolp.unregisterSingularity(IERC20(address(toftSglEthMarket)));
    }

    function test_RevertWhen_AssetId0() external {
        // it should revert
        vm.startPrank(adminAddr);

        vm.expectRevert(NotRegistered.selector);
        tolp.unregisterSingularity(IERC20(address(toftSglEthMarket)));
    }

    function test_RevertWhen_NotInRescue() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);

        vm.expectRevert(NotInRescueMode.selector);
        tolp.unregisterSingularity(IERC20(address(toftSglEthMarket)));
    }

    function test_ShouldUnregisterTheSingularity()
        external
        registerSingularityPool
        setSglInRescue(IERC20(address(toftSglEthMarket)), ybAssetIdToftSglEthMarket)
    {
        // it should unregister the singularity
        vm.startPrank(adminAddr);

        tolp.unregisterSingularity(IERC20(address(toftSglEthMarket)));
        //     delete the activeSingularities
        (uint256 assetId,,,) = tolp.activeSingularities(IERC20(address(toftSglEthMarket)));
        assertEq(assetId, 0, "TOLP_unregisterSingularity: Invalid assetId");
        //     delete sglAssetIDToAddress
        assertEq(
            address(tolp.sglAssetIDToAddress(ybAssetIdToftSglEthMarket)),
            address(0),
            "TOLP_unregisterSingularity: Invalid sglAssetToAddress"
        );
        //     delete sglRescueRequest
        assertEq(
            tolp.sglRescueRequest(ybAssetIdToftSglEthMarket), 0, "TOLP_unregisterSingularity: Invalid sglRescueRequest"
        );
        //     delete singularities array
        assertEq(tolp.getSingularities().length, 4, "TOLP_unregisterSingularity: Invalid singularities array");
    }
}
