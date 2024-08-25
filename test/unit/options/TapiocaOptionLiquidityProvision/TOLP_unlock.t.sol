// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TolpBaseTest, IERC20, TapiocaOptionLiquidityProvision} from "./TolpBaseTest.sol";
import {LockPosition} from "contracts/options/TapiocaOptionLiquidityProvision.sol";

contract TOLP_unlock is TolpBaseTest {
    uint256 constant TOLP_TOKEN_ID = 1;
    IERC20 SGL_ADDRESS;
    uint256 SGL_ASSET_ID;

    function setUp() public virtual override {
        super.setUp();
        SGL_ADDRESS = IERC20(address(singularityEthMarket));
        SGL_ASSET_ID = singularityEthMarketAssetId;
    }

    function test_RevertWhen_Paused(uint128 _weight, uint128 _lockDuration)
        external
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
    {
        vm.prank(adminAddr);
        tolp.setPause(true);
        // it should revert
        vm.expectRevert("Pausable: paused");
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_RevertWhen_PositionIsExpired(uint128 _weight, uint128 _lockDuration)
        external
        whenNotPaused
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
    {
        (_weight, _lockDuration) = _boundValues(_weight, _lockDuration);
        skip(_lockDuration);
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.PositionExpired.selector);
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);
    }

    modifier whenPositionIsNotExpired() {
        _;
    }

    /**
     * @notice Sends the token to an address to mimic tOB holding the token
     */
    modifier whenTobIsHolderOfTheToken() {
        // Setup Pearlmit approval
        vm.prank(aliceAddr);
        tolp.transferFrom(aliceAddr, address(bobAddr), TOLP_TOKEN_ID);
        vm.prank(adminAddr);
        tolp.setTapiocaOptionBroker(bobAddr);
        _;
    }

    function test_RevertWhen_TobIsHolderOfTheToken(uint128 _weight, uint128 _lockDuration)
        external
        whenNotPaused
        whenPositionIsNotExpired
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
        whenTobIsHolderOfTheToken
    {
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.TobIsHolder.selector);
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);
    }

    modifier whenUserIsHolderOfTheToken() {
        _;
    }

    modifier whenLockIsNotExpired() {
        _;
    }

    function test_RevertWhen_SglIsNotInRescue(uint128 _weight, uint128 _lockDuration)
        external
        whenNotPaused
        whenPositionIsNotExpired
        whenUserIsHolderOfTheToken
        whenLockIsNotExpired
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionLiquidityProvision.LockNotExpired.selector);
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);
    }

    function test_WhenSglIsInRescue(uint128 _weight, uint128 _lockDuration)
        external
        whenNotPaused
        whenPositionIsNotExpired
        whenUserIsHolderOfTheToken
        whenLockIsNotExpired
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
    {
        vm.startPrank(adminAddr);
        tolp.setRescueCooldown(0);
        tolp.requestSglPoolRescue(SGL_ASSET_ID);
        tolp.activateSGLPoolRescue(SGL_ADDRESS);
        // it should continue
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);
    }

    modifier whenLockIsExpired(uint128 _lockDuration) {
        (, _lockDuration) = _boundValues(0, _lockDuration);
        skip(_lockDuration);
        _;
    }

    modifier whenContinuing() {
        _;
    }

    function test_RevertWhen_SglAssetIdDoesntMatch(uint128 _weight, uint128 _lockDuration)
        external
        whenNotPaused
        whenPositionIsNotExpired
        whenUserIsHolderOfTheToken
        whenContinuing
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
        whenLockIsExpired(_lockDuration)
    {
        // it should revert
        vm.skip(true); // @dev see TODO in `tOLP::unlock()`
    }

    function test_WhenSglAssetIdMatches(uint128 _weight, uint128 _lockDuration)
        external
        whenNotPaused
        whenPositionIsNotExpired
        whenUserIsHolderOfTheToken
        whenContinuing
        initAndCreateLock(aliceAddr, _weight, _lockDuration)
        whenLockIsExpired(_lockDuration)
    {
        (_weight,) = _boundValues(_weight, _lockDuration);

        // it should emit Burn
        vm.expectEmit(true, true, true, true);
        emit TapiocaOptionLiquidityProvision.Burn(aliceAddr, SGL_ASSET_ID, address(SGL_ADDRESS), TOLP_TOKEN_ID);
        tolp.unlock(TOLP_TOKEN_ID, SGL_ADDRESS);

        // it should burn the token
        vm.expectRevert("ERC721: invalid token ID");
        tolp.ownerOf(TOLP_TOKEN_ID);

        // it should delete the lock position
        LockPosition memory lockPosition = tolp.getLock(TOLP_TOKEN_ID);
        assertEq(lockPosition.sglAssetID, 0, "TOLP_unlock::test_WhenSglAssetIdMatches: Invalid sglAssetID");
        assertEq(lockPosition.ybShares, 0, "TOLP_unlock::test_WhenSglAssetIdMatches: Invalid ybShares");
        assertEq(lockPosition.lockTime, 0, "TOLP_unlock::test_WhenSglAssetIdMatches: Invalid lockTime");
        assertEq(lockPosition.lockDuration, 0, "TOLP_unlock::test_WhenSglAssetIdMatches: Invalid lockDuration");

        // it should transfer the yieldbox sgl shares
        assertEq(
            yieldBox.balanceOf(aliceAddr, SGL_ASSET_ID),
            _weight,
            "TOLP_unlock::test_WhenSglAssetIdMatches: Invalid balance"
        );

        // it should decrement total deposited
        (, uint256 totalDeposited,,) = tolp.activeSingularities(SGL_ADDRESS);
        assertEq(totalDeposited, 0, "TOLP_unlock::test_WhenSglAssetIdMatches: Invalid totalDeposited");
    }
}
