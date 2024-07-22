// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";

contract twTap_batchClaimRewards is twTapBaseTest {
    function test_RevertWhen_Paused() external {
        // it should revert
        vm.prank(adminAddr);
        twTap.setPause(true);

        vm.expectRevert("Pausable: paused");
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        twTap.batchClaimRewards(tokenIds);
    }

    function test_ShouldReturnTheClaimableRewards()
        external
        participate(100, 1)
        participate(100, 1)
        skipWeeks(1)
        advanceWeeks(1)
        distributeRewards
    {
        // it should return the claimable rewards
        vm.startPrank(aliceAddr);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        twTap.batchClaimRewards(tokenIds);
    }
}
