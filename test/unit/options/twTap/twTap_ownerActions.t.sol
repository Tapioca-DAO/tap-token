// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {twTapBaseTest, TwTAP} from "test/unit/options/twTap/twTapBaseTest.sol";
import {ICluster} from "tap-utils/interfaces/periph/ICluster.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract twTap_ownerActions is twTapBaseTest {
    function test_RevertWhen_AdvancingWeekAndNotOwner() external skipWeeks(1) {
        // it should revert
        vm.expectRevert(TwTAP.NotAuthorized.selector);
        twTap.advanceWeek(1);

        vm.startPrank(adminAddr);
        cluster.setRoleForContract(aliceAddr, keccak256("NEW_EPOCH"), true);
        vm.expectEmit(true, true, false, false);
        emit TwTAP.AdvanceEpoch(1, 0);
        twTap.advanceWeek(1);
    }

    function test_RevertWhen_SetRescueModeAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.setRescueMode(true);
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.setRescueMode(false);

        vm.startPrank(adminAddr);
        twTap.setRescueMode(true);
        assertEq(
            twTap.rescueMode(),
            true,
            "twTap_ownerActions::test_RevertWhen_SetRescueModeAndNotOwner: Invalid rescue mode"
        );
        twTap.setRescueMode(false);
        assertEq(
            twTap.rescueMode(),
            false,
            "twTap_ownerActions::test_RevertWhen_SetRescueModeAndNotOwner: Invalid rescue mode"
        );
    }

    function test_RevertWhen_SetVirtualTotalAmountAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.setVirtualTotalAmount(1e20);

        vm.startPrank(adminAddr);
        twTap.setVirtualTotalAmount(1e20);
        assertEq(
            twTap.VIRTUAL_TOTAL_AMOUNT(),
            1e20,
            "twTap_ownerActions::test_RevertWhen_SetVirtualTotalAmountAndNotOwner: Invalid virtual total amount"
        );
    }

    function test_RevertWhen_SetMinWeightFactorAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.setMinWeightFactor(1e20);

        vm.startPrank(adminAddr);
        twTap.setMinWeightFactor(1e20);
        assertEq(
            twTap.MIN_WEIGHT_FACTOR(),
            1e20,
            "twTap_ownerActions::test_RevertWhen_setMinWeightFactorAndNotOwner: Invalid min weight factor"
        );
    }

    function test_RevertWhen_SetMaxRewardTokensLengthAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.setMaxRewardTokensLength(100);

        vm.startPrank(adminAddr);
        twTap.setMaxRewardTokensLength(100);
        assertEq(
            twTap.maxRewardTokens(),
            100,
            "twTap_ownerActions::test_RevertWhen_setMaxRewardTokensLengthAndNotOwner: Invalid max reward tokens length"
        );
    }

    function test_RevertWhen_AddRewardTokenAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.addRewardToken(IERC20(address(daiMock)));

        vm.startPrank(adminAddr);
        vm.expectEmit(true, true, false, false);
        emit TwTAP.AddRewardToken(address(daiMock), 1);
        twTap.addRewardToken(IERC20(address(daiMock)));
        assertEq(
            address(twTap.rewardTokens(1)),
            address(daiMock),
            "twTap_ownerActions::test_RevertWhen_addRewardTokenAndNotOwner: Invalid reward token"
        );
    }

    function test_RevertWhen_SetClusterAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.setCluster(ICluster(address(0x1)));

        vm.startPrank(adminAddr);
        twTap.setCluster(ICluster(address(0x1)));
        assertEq(
            address(twTap.cluster()),
            address(0x1),
            "twTap_ownerActions::test_RevertWhen_setClusterAndNotOwner: Invalid cluster address"
        );
    }

    function test_RevertWhen_SetPauseAndNotOwner() external {
        // it should revert
        vm.expectRevert(TwTAP.NotAuthorized.selector);
        twTap.setPause(true);
        vm.expectRevert(TwTAP.NotAuthorized.selector);
        twTap.setPause(false);

        vm.startPrank(adminAddr);
        twTap.setPause(true);
        assertEq(twTap.paused(), true, "twTap_ownerActions::test_RevertWhen_setPauseAndNotOwner: Invalid pause");
        twTap.setPause(false);
        assertEq(twTap.paused(), false, "twTap_ownerActions::test_RevertWhen_setPauseAndNotOwner: Invalid pause");

        cluster.setRoleForContract(aliceAddr, keccak256("PAUSABLE"), true);
        vm.startPrank(aliceAddr);
        twTap.setPause(true);
        assertEq(twTap.paused(), true, "twTap_ownerActions::test_RevertWhen_setPauseAndNotOwner: Invalid pause");
        twTap.setPause(false);
        assertEq(twTap.paused(), false, "twTap_ownerActions::test_RevertWhen_setPauseAndNotOwner: Invalid pause");
    }

    function test_RevertWhen_SetEmergencySweepCooldownAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.setEmergencySweepCooldown(20 days);

        vm.startPrank(adminAddr);
        twTap.setEmergencySweepCooldown(20 days);
        assertEq(
            twTap.emergencySweepCooldown(),
            20 days,
            "twTap_ownerActions::test_RevertWhen_setEmergencySweepCooldownAndNotOwner: Invalid emergency sweep cooldown"
        );
    }

    function test_RevertWhen_ActivateEmergencySweepAndNotOwner() external {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        twTap.activateEmergencySweep();

        vm.startPrank(adminAddr);
        twTap.activateEmergencySweep();
        assertEq(
            twTap.lastEmergencySweep(),
            block.timestamp,
            "twTap_ownerActions::test_RevertWhen_activateEmergencySweepAndNotOwner: Invalid last emergency sweep"
        );
    }
}
