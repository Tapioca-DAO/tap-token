// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {TapOption} from "contracts/options/oTAP.sol";

contract TOB_participate is TobBaseTest {
    function test_RevertWhen_LockExpired() external registerSingularityPool createLock(100, 0) skipEpochs(2) {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.LockExpired.selector);
        tob.participate(1);
    }

    function test_RevertWhen_EpochNotAdvanced() external registerSingularityPool createLock(100, 3) skipEpochs(1) {
        // it should revert
        skip(tob.EPOCH_DURATION());

        vm.expectRevert(TapiocaOptionBroker.AdvanceEpochFirst.selector);
        tob.participate(1);
    }

    function test_RevertWhen_OptionExpired() external {
        // it should revert
        vm.skip(true);
        // TODO remove -  Check comment on the revert
    }

    function test_RevertWhen_DurationTooShort() external {
        // it should revert
        vm.skip(true);
        // TODO remove -  Check comment on the revert
    }

    function test_RevertWhen_DurationNotMultipleOfEpochDuration() external registerSingularityPool {
        // it should revert
        _createLock(100, uint128(tob.EPOCH_DURATION() + 1));
        vm.startPrank(adminAddr);
        tob.init();
        skip(tob.EPOCH_DURATION());
        tob.newEpoch();

        vm.expectRevert(TapiocaOptionBroker.DurationNotMultiple.selector);
        tob.participate(1);
    }

    function test_RevertWhen_PearlmitTransferFailed()
        external
        registerSingularityPool
        createLock(100, 2)
        skipEpochs(1)
    {
        // it should revert
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(721, address(tolp), 1, address(tob), 1, uint48(block.timestamp + 1));

        vm.expectRevert(TapiocaOptionBroker.TransferFailed.selector);
        tob.participate(1);
    }

    function test_RevertWhen_LockIsLongerThanMaxLockDuration()
        external
        registerSingularityPool
        createLock(100, 5)
        skipEpochs(1)
    {
        // it should revert
        vm.startPrank(aliceAddr);
        tolp.approve(address(pearlmit), 1);
        pearlmit.approve(721, address(tolp), 1, address(tob), 1, uint48(block.timestamp + 1));

        vm.expectRevert(TapiocaOptionBroker.TooLong.selector);
        tob.participate(1);
    }

    function test_ShouldParticipate() external registerSingularityPool createLock(100, 2) skipEpochs(1) {
        // it should participate
        vm.startPrank(aliceAddr);
        tolp.approve(address(pearlmit), 1);
        pearlmit.approve(721, address(tolp), 1, address(tob), 1, uint48(block.timestamp + 1));

        vm.expectEmit(true, true, false, false);
        emit TapiocaOptionBroker.Participate(1, 1, 100, 1, 0, 0);
        tob.participate(1);

        (,,uint128 tolpLockTime,) = tolp.lockPositions(1);
        (uint128 entry, uint128 expiry, uint128 discount, uint256 tolpId) = otap.options(1);
        assertEq(entry, block.timestamp, "TOB_participate::test_ShouldParticipate: Invalid entry");
        assertEq(expiry, tolpLockTime + (2 * tob.EPOCH_DURATION()), "TOB_participate::test_ShouldParticipate: Invalid expiry");
        assertEq(discount, 500000, "TOB_participate::test_ShouldParticipate: Invalid discount");
        assertEq(tolpId, 1, "TOB_participate::test_ShouldParticipate: Invalid tOLP ID");
    }
}
