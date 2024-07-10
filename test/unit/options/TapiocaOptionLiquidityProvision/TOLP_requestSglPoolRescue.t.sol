// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20} from "./TolpBaseTest.sol";

contract TOLP_requestSglPoolRescue is TolpBaseTest {
    function test_ShouldRequestTheSglPoolToRescueWithTheBlockTimestamp() external registerSingularityPool {
        // it should request the sgl pool to rescue with the block timestamp
        vm.startPrank(adminAddr);

        tolp.requestSglPoolRescue(1);
        assertEq(tolp.sglRescueRequest(1), block.timestamp, "TOLP_requestSglPoolRescue: Invalid rescue request");
    }

    function test_RevertWhen_SglAssetIdIs0() external {
        // it should revert
        vm.startPrank(adminAddr);
        vm.expectRevert(NotRegistered.selector);
        tolp.requestSglPoolRescue(0);
    }

    function test_RevertWhen_SglRescueIsAlreadyActivated() external registerSingularityPool {
        // it should revert
        vm.startPrank(adminAddr);
        tolp.requestSglPoolRescue(1);
        vm.expectRevert(AlreadyActive.selector);
        tolp.requestSglPoolRescue(1);
    }
}
