// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker, IERC20} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";

contract TOB_exitPosition is TobBaseTest {
    uint128 public constant TOLP_LOCK_DURATION = 1; // in weeks
    uint256 public constant OTAP_TOKEN_ID = 1;
    uint256 public constant TOLP_TOKEN_ID = 1;

    function test_RevertWhen_PositionDoesntExist() external {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.PositionNotValid.selector);
        tob.exitPosition(OTAP_TOKEN_ID);
    }

    modifier whenPositionExists(uint256 __tOLPLockAmount) {
        _setupAndParticipate(aliceAddr, __tOLPLockAmount, TOLP_LOCK_DURATION);
        vm.assume(__tOLPLockAmount > 0);
        _;
    }

    modifier whenLockIsNotExpired() {
        _;
    }

    function test_WhenSglIsInRescueMode(uint256 __tOLPLockAmount)
        external
        whenPositionExists(__tOLPLockAmount)
        whenLockIsNotExpired
        setSglInRescue(IERC20(address(0x1)), 1)
    {
        (,,, uint256 cumulativeBefore) = tob.twAML(1);
        // it should continue
        tob.exitPosition(OTAP_TOKEN_ID);
        // it should bypass twAML changes
        (,,, uint256 cumulativeAfter) = tob.twAML(1);
        assertEq(cumulativeBefore, cumulativeAfter, "TOB_exitPosition::test_WhenSglIsInRescueMode: Invalid cumulative");
    }

    function test_RevertWhen_SglIsNotInRescueMode(uint256 __tOLPLockAmount)
        external
        whenPositionExists(__tOLPLockAmount)
        whenLockIsNotExpired
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.LockNotExpired.selector);
        tob.exitPosition(OTAP_TOKEN_ID);
    }

    function test_WhenLockIsExpired(uint256 __tOLPLockAmount)
        external
        whenPositionExists(__tOLPLockAmount)
        skipEpochs(1)
    {
        uint256 epoch = 1;
        address paymentToken = address(daiMock);
        (,,, uint256 cumulativeBefore) = tob.twAML(1);

        // it should emit ExitPosition
        vm.expectEmit(true, true, true, false);
        emit TapiocaOptionBroker.ExitPosition(epoch, OTAP_TOKEN_ID, OTAP_TOKEN_ID);
        tob.exitPosition(OTAP_TOKEN_ID);
        (uint256 totalParticipants,, uint256 totalDeposited, uint256 cumulativeAfter) = tob.twAML(1);

        // it should update twAML cumulative
        assertLt(cumulativeAfter, cumulativeBefore, "TOB_exitPosition::test_WhenLockIsExpired: Invalid cumulative");
        assertEq(totalParticipants, 0, "TOB_exitPosition::test_WhenLockIsExpired: Invalid totalParticipants");
        assertEq(totalDeposited, 0, "TOB_exitPosition::test_WhenLockIsExpired: Invalid totalDeposited");

        // it should delete participation mapping
        (bool hasVotingPower, bool divergenceForce, uint256 userAverageMagnitude) = tob.participants(OTAP_TOKEN_ID);
        assertEq(hasVotingPower, false, "TOB_exitPosition::test_WhenLockIsExpired: Invalid hasVotingPower");
        assertEq(divergenceForce, false, "TOB_exitPosition::test_WhenLockIsExpired: Invalid divergenceForce");
        assertEq(userAverageMagnitude, 0, "TOB_exitPosition::test_WhenLockIsExpired: Invalid userAverageMagnitude");

        // it should burn the oTAP
        vm.expectRevert("ERC721: invalid token ID");
        otap.ownerOf(OTAP_TOKEN_ID);

        // it should transfer the tOLP to the oTAP owner
        assertEq(tolp.ownerOf(TOLP_TOKEN_ID), aliceAddr, "TOB_exitPosition::test_WhenLockIsExpired: Invalid tOLP owner");
    }
}
