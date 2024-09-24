// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20, TapiocaOptionLiquidityProvision} from "./TolpBaseTest.sol";
import {LockPosition, SingularityPool} from "contracts/options/TapiocaOptionLiquidityProvision.sol";

import "forge-std/console.sol";

contract TOLP_lock is TolpBaseTest {
    IERC20 public SGL_TO_LOCK;
    uint256 public SGL_ASSET_ID;

    function setUp() public virtual override {
        super.setUp();
        SGL_TO_LOCK = IERC20(address(toftSglEthMarket));
        SGL_ASSET_ID = ybAssetIdToftSglEthMarket;
    }

    function test_RevertWhen_PausedPaused(uint128 _lockDuration, uint128 _ybShares) external {
        vm.prank(adminAddr);
        tolp.setPause(true);
        // it should revert
        vm.expectRevert("Pausable: paused");
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_RevertWhen_DurationIsTooShort(uint128 _lockDuration, uint128 _ybShares) external whenNotPaused {
        _lockDuration = uint128(bound(_lockDuration, 0, tolp.EPOCH_DURATION() - 1));
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.DurationTooShort.selector);
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenDurationIsNotTooShort() {
        _;
    }

    function test_RevertWhen_DurationIsTooLong(uint128 _lockDuration, uint128 _ybShares)
        external
        whenNotPaused
        whenDurationIsNotTooShort
    {
        _lockDuration = uint128(bound(_lockDuration, tolp.MAX_LOCK_DURATION() + 1, type(uint128).max));
        vm.assume(_ybShares != 0);
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.DurationTooLong.selector);
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenDurationIsRight() {
        _;
    }

    function _whenDurationIsRight(uint128 _lockDuration) internal returns (uint128) {
        uint256 epochDuration = tolp.EPOCH_DURATION();
        uint256 maxLockDuration = tolp.MAX_LOCK_DURATION();
        return uint128(bound(_lockDuration, 1, maxLockDuration / epochDuration) * epochDuration);
    }

    function test_RevertWhen_SharesEqualTo0(uint128 _lockDuration)
        external
        whenNotPaused
        whenDurationIsNotTooShort
        whenDurationIsRight
    {
        _lockDuration = _whenDurationIsRight(_lockDuration);
        uint128 _ybShares = 0;
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.SharesNotValid.selector);
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenSharesBiggerThan0(uint128 _ybShares) {
        vm.assume(_ybShares != 0);
        _;
    }

    function test_RevertWhen_SglIsInRescueMode(uint128 _lockDuration, uint128 _ybShares)
        external
        whenNotPaused
        whenDurationIsNotTooShort
        whenSharesBiggerThan0(_ybShares)
        whenDurationIsRight
        registerSingularityPool
        setPoolRescue
    {
        _lockDuration = _whenDurationIsRight(_lockDuration);
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.SingularityInRescueMode.selector);
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenSglNotInRescueMode() {
        _;
    }

    function test_RevertWhen_RescueCooldownActivated(uint128 _lockDuration, uint128 _ybShares)
        external
        whenNotPaused
        whenDurationIsNotTooShort
        whenSharesBiggerThan0(_ybShares)
        whenDurationIsRight
        whenSglNotInRescueMode
        registerSingularityPool
    {
        _lockDuration = _whenDurationIsRight(_lockDuration);
        vm.prank(adminAddr);
        tolp.activateEmergencySweep();
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.EmergencySweepActivated.selector);
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenRescueCooldownNotActivated() {
        _;
    }

    function test_RevertWhen_SglNotActive(uint128 _lockDuration, uint128 _ybShares)
        external
        whenNotPaused
        whenDurationIsNotTooShort
        whenDurationIsRight
        whenSharesBiggerThan0(_ybShares)
        whenSglNotInRescueMode
        whenRescueCooldownNotActivated
    {
        _lockDuration = _whenDurationIsRight(_lockDuration);
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.SingularityNotActive.selector);
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenSglIsActive() {
        _registerSingularityPool();
        _;
    }

    function test_RevertWhen_PearlmitTransferFails(uint128 _lockDuration, uint128 _ybShares)
        external
        whenNotPaused
        whenDurationIsNotTooShort
        whenDurationIsRight
        whenSharesBiggerThan0(_ybShares)
        whenSglNotInRescueMode
        whenRescueCooldownNotActivated
        whenSglIsActive
    {
        _lockDuration = _whenDurationIsRight(_lockDuration);
        // it should revert
        // It should be TapiocaOptionLiquidityProvision.TransferFailed.selector,
        // for simplicity we use vm.expectRevert() if we don't permit it
        vm.expectRevert();
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);
    }

    modifier whenTransferSucceeds(uint128 _ybShares) {
        _resetPrank({caller: aliceAddr});
        (_ybShares,) = _boundValues(_ybShares, 0);
        yieldBox.depositAsset(SGL_ASSET_ID, aliceAddr, _ybShares);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(1155, address(yieldBox), SGL_ASSET_ID, address(tolp), _ybShares, uint48(block.timestamp + 1));
        _;
    }

    modifier depositingCollateralToBigBang(uint128 _ybShares) {
        (_ybShares,) = _boundValues(_ybShares, 0);
        depositBBCollateral(aliceAddr, _ybShares);
        _;
    }

    uint256 constant EXPECTED_TOKEN_ID = 1;

    function test_WhenPearlmitTransferSucceed(uint128 _lockDuration, uint128 _ybShares)
        external
        whenNotPaused
        whenDurationIsNotTooShort
        whenDurationIsRight
        whenSharesBiggerThan0(_ybShares)
        whenSglNotInRescueMode
        whenRescueCooldownNotActivated
        whenSglIsActive
        depositingCollateralToBigBang(_ybShares)
        whenTransferSucceeds(_ybShares)
    {
        _lockDuration = _whenDurationIsRight(_lockDuration);
        (_ybShares,) = _boundValues(_ybShares, 0);

        // it should emit Mint event
        vm.expectEmit(true, true, true, false);
        emit Mint(aliceAddr, SGL_ASSET_ID, address(SGL_TO_LOCK), EXPECTED_TOKEN_ID, _lockDuration, _ybShares);
        tolp.lock(aliceAddr, SGL_TO_LOCK, _lockDuration, _ybShares, aliceAddr);

        // it should mint a tOLP position
        assertEq(tolp.balanceOf(aliceAddr), 1, "TOLP_lock::test_WhenPearlmitTransferSucceed: Invalid balance");

        // it should add shares to the sgl total deposited
        (, uint256 totalDeposited,,) = tolp.activeSingularities(SGL_TO_LOCK);
        assertEq(totalDeposited, _ybShares, "TOLP_lock::test_WhenPearlmitTransferSucceed: Invalid totalDeposited");

        // it should create a lock position with the right data
        LockPosition memory lock = tolp.getLock(EXPECTED_TOKEN_ID);
        assertEq(lock.sglAssetID, SGL_ASSET_ID, "TOLP_lock::test_WhenPearlmitTransferSucceed: Invalid sglAssetID");
        assertEq(lock.lockDuration, _lockDuration, "TOLP_lock::test_WhenPearlmitTransferSucceed: Invalid lockDuration");
        assertEq(lock.ybShares, _ybShares, "TOLP_lock::test_WhenPearlmitTransferSucceed: Invalid shares");
        assertEq(lock.lockTime, block.timestamp, "TOLP_lock::test_WhenPearlmitTransferSucceed: Invalid lockTime");
    }
}
