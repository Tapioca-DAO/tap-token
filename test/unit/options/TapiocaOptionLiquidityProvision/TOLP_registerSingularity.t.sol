// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20} from "./TolpBaseTest.sol";

contract TOLP_registerSingularity is TolpBaseTest {
    function test_RevertWhen_NotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        tolp.registerSingularity(IERC20(address(0x1)), 1, 0);
    }

    function test_RevertWhen_AssetIdNotValid() external {
        // it should revert
        vm.startPrank(adminAddr);

        vm.expectRevert(AssetIdNotValid.selector);
        tolp.registerSingularity(IERC20(address(0x1)), 0, 0);
    }

    function test_RevertWhen_AssetIdAlreadyRegistered() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);

        vm.expectRevert(DuplicateAssetId.selector);
        tolp.registerSingularity(IERC20(address(0x1)), 1, 0);
    }

    function test_RevertWhen_SglIsAlreadyRegistered() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);

        vm.expectRevert(AlreadyRegistered.selector);
        tolp.registerSingularity(IERC20(address(0x1)), 10, 0);
    }

    function test_ShouldRegisterTheSingularity() external registerSingularityPool {
        // it should register the singularity
        vm.startPrank(adminAddr);

        tolp.registerSingularity(IERC20(address(0x6)), 6, 0);
        //     update the activeSingularities
        (uint256 assetId,,,) = tolp.activeSingularities(IERC20(address(0x6)));
        assertEq(assetId, 6, "TOLP_registerSingularity::test_ShouldRegisterTheSingularity: Invalid assetId");
        //     register sglAssetIDToAddress
        assertEq(
            address(tolp.sglAssetIDToAddress(6)),
            address(0x6),
            "TOLP_registerSingularity::test_ShouldRegisterTheSingularity: Invalid sglAssetToAddress"
        );
        //     updateTotalSGLPoolWeights
        assertEq(
            tolp.totalSingularityPoolWeights(),
            6,
            "TOLP_registerSingularity::test_ShouldRegisterTheSingularity: Invalid total weight"
        );
    }
}
