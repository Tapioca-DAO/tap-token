// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20, TapiocaOptionLiquidityProvision} from "./TolpBaseTest.sol";
import {LockPosition} from "contracts/options/TapiocaOptionLiquidityProvision.sol";
import {Module as BBModule} from "tap-utils/interfaces/bar/IMarket.sol";

contract TOLP_getDebtPenaltyAmount is TolpBaseTest {
    uint256 constant TOLP_TOKEN_ID = 1;
    IERC20 SGL_ADDRESS;
    uint256 SGL_ASSET_ID;

    function setUp() public virtual override {
        super.setUp();
        SGL_ADDRESS = IERC20(address(toftSglEthMarket));
        SGL_ASSET_ID = ybAssetIdToftSglEthMarket;
    }

    function test_WhenUserIsLockedAndDoesNotHaveEnoughBBDebt(uint128 _weight, uint128 _lockDuration)
        external
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
    {
        (_weight,) = _boundValues(_weight, _lockDuration);
        _repayDebt(aliceAddr, bigBangEthMarket._userBorrowPart(aliceAddr) / 2);
        vm.prank(adminAddr);
        tolp.setMaxDebtBuffer(100000);
        (bool canLock,,) = tolp.canLockWithDebt(aliceAddr, SGL_ASSET_ID, tolp.userLockedUsdo(aliceAddr));
        assertEq(canLock, false, "TOLP_getDebtPenaltyAmount::test_WhenUserIsLockedAndDoesNotHaveEnoughBBDebt canLock");
        // it should unlock earlier
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);
        // it should apply the penalty
        uint256 penalty = tolp.totalPenalties(SGL_ASSET_ID);
        assertGt(penalty, 0, "TOLP_getDebtPenaltyAmount::test_WhenUserIsLockedAndDoesNotHaveEnoughBBDebt penalty");
        // it should allow admin to withdraw the penalty
        cluster.setRoleForContract(adminAddr, keccak256("HARVEST_TOLP"), true);
        tolp.harvestPenalties(adminAddr, penalty, SGL_ASSET_ID);
        assertEq(
            yieldBox.toAmount(SGL_ASSET_ID, yieldBox.balanceOf(adminAddr, SGL_ASSET_ID), false),
            penalty,
            "TOLP_getDebtPenaltyAmount::test_WhenUserIsLockedAndDoesNotHaveEnoughBBDebt penalty harvest"
        );
    }

    function _repayDebt(address _user, uint256 _amount) internal {
        vm.startPrank(_user);
        // approvals
        usdoMock.approve(address(yieldBox), type(uint256).max);
        usdoMock.approve(address(pearlmit), type(uint256).max);
        yieldBox.setApprovalForAll(address(bigBangEthMarket), true);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(
            1155,
            address(yieldBox),
            usdoMockTokenId,
            address(bigBangEthMarket),
            type(uint200).max,
            uint48(block.timestamp)
        );

        // repay the debt
        deal(address(usdoMock), _user, _amount);
        uint256 share = yieldBox.toShare(usdoMockTokenId, _amount, false);
        yieldBox.depositAsset(usdoMockTokenId, _user, share);

        (BBModule[] memory modules, bytes[] memory calls) = marketHelper.repay(_user, _user, false, _amount);
        bigBangEthMarket.execute(modules, calls, true);
        vm.stopPrank();
    }
}
