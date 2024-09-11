// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {TapOption} from "contracts/options/oTAP.sol";
import {LockPosition} from "contracts/options/TapiocaOptionLiquidityProvision.sol";
import {TWAML} from "contracts/options/twAML.sol";

contract TOB_participate is TobBaseTest, TWAML {
    uint256 constant TOLP_TOKEN_ID = 1;
    uint128 constant WEEK_LONG = 1;
    uint256 constant VIRTUAL_TOTAL_AMOUNT = 50_000 ether; // @See TapiocaOptionBroker
    uint256 SGL_ASSET_ID; // Check TobBaseTest::createLock()

    function setUp() public virtual override {
        super.setUp();
        SGL_ASSET_ID = ybAssetIdToftSglEthMarket;
    }

    /**
     * @notice Initialize the tests and create a lock
     * - Register the Singularity Pool
     * - Initialize the Tapioca Option Broker
     * - Create a tOLP lock
     */
    modifier initTestsAndCreateLock(uint128 _lockAmount, uint128 _lockDuration) {
        (, _lockDuration) = _boundValues(0, _lockDuration);
        _lockAmount = uint128(
            bound(
                _lockAmount,
                computeMinWeight(VIRTUAL_TOTAL_AMOUNT, tob.MIN_WEIGHT_FACTOR()),
                MAX_USDO_PARTICIPATION_BOUNDARY
            )
        );
        _initTestsAndCreateLock(_lockAmount, _lockDuration);
        _;
    }

    modifier initTestsAndCreateLockWithNoDurationBound(uint128 _lockAmount, uint128 _lockDuration) {
        (_lockAmount,) = _boundValues(_lockAmount, 0);
        _initTestsAndCreateLock(_lockAmount, _lockDuration);
        _;
    }

    /**
     * @notice Concrete implementation of the modifier initTestsAndCreateLock
     */
    function _initTestsAndCreateLock(uint128 _lockAmount, uint128 _lockDuration)
        internal
        registerSingularityPool
        tobInit
        createLock(aliceAddr, _lockAmount, _lockDuration)
    {}

    /**
     * @notice Calls different approvals for the Pearlmit contract
     */
    modifier setupPearlmitApproval() {
        _setupPearlmitApproval();
        _;
    }

    function _setupPearlmitApproval() internal {
        _resetPrank({caller: aliceAddr});
        yieldBox.setApprovalForAll(address(pearlmit), true);
        tolp.approve(address(pearlmit), TOLP_TOKEN_ID);
        pearlmit.approve(721, address(tolp), TOLP_TOKEN_ID, address(tob), 1, uint48(block.timestamp + 1));
    }

    function test_RevertWhen_Paused() external {
        vm.prank(adminAddr);
        tob.setPause(true);
        // it should revert
        vm.expectRevert("Pausable: paused");
        tob.participate(TOLP_TOKEN_ID, 0);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_RevertWhen_LockExpired(uint128 _lockAmount)
        external
        whenNotPaused
        initTestsAndCreateLock(_lockAmount, WEEK_LONG)
        skipEpochs(1)
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.LockExpired.selector);
        tob.participate(TOLP_TOKEN_ID, 0);
    }

    modifier whenLockNotExpired() {
        _;
    }

    function test_RevertWhen_EpochNotAdvanced(uint128 _lockAmount, uint128 _lockDuration)
        external
        whenNotPaused
        whenLockNotExpired
        initTestsAndCreateLock(_lockAmount, WEEK_LONG * 2)
    {
        skip(tob.EPOCH_DURATION());
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.AdvanceEpochFirst.selector);
        tob.participate(TOLP_TOKEN_ID, 0);
    }

    modifier whenEpochIsAdvanced() {
        _;
    }

    function test_RevertWhen_PositionExpired() external whenNotPaused whenLockNotExpired whenEpochIsAdvanced {
        // it should revert
        vm.skip(true);
        // TODO remove -  Check comment on the revert
    }

    modifier whenPositionIsActive() {
        _;
    }

    function test_RevertWhen_LockDurationTooSmall()
        external
        whenNotPaused
        whenLockNotExpired
        whenEpochIsAdvanced
        whenPositionIsActive
    {
        // it should revert
        vm.skip(true);
        // TODO remove -  Check comment on the revert
    }

    modifier whenLockDurationIsBigEnough() {
        _;
    }

    function test_RevertWhen_LockDurationIsNotAMultipleOfEpochDuration(uint128 _lockAmount)
        external
        whenNotPaused
        whenLockNotExpired
        whenEpochIsAdvanced
        whenPositionIsActive
        whenLockDurationIsBigEnough
    // initTestsAndCreateLockWithNoDurationBound(_lockAmount, uint128(tob.EPOCH_DURATION() + 1))
    {
        vm.skip(true); // Check is redundant, already done in `tOLP.lock()` function
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.DurationNotMultiple.selector);
        tob.participate(TOLP_TOKEN_ID, 0);
    }

    modifier whenLockDurationIsAMultipleOfEpochDuration() {
        _;
    }

    function test_RevertWhen_PearlmitTransferFails(uint128 _lockAmount, uint128 _lockDuration)
        external
        whenNotPaused
        whenLockNotExpired
        whenEpochIsAdvanced
        whenPositionIsActive
        whenLockDurationIsBigEnough
        whenLockDurationIsAMultipleOfEpochDuration
        initTestsAndCreateLock(_lockAmount, _lockDuration)
    {
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(721, address(tolp), TOLP_TOKEN_ID, address(tob), 1, uint48(block.timestamp + 1));

        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TransferFailed.selector);
        tob.participate(TOLP_TOKEN_ID, 0);
    }

    modifier whenPearlmitTransferSucceed() {
        _;
    }

    uint256 public constant MAX_REWARD = 500_001; // See @TapiocaOptionBroker::dMax

    function test_RevertWhen_RewardsAreLowerThanMinReward(uint128 _lockAmount, uint128 _lockDuration)
        external
        whenNotPaused
        whenLockNotExpired
        whenEpochIsAdvanced
        whenPositionIsActive
        whenLockDurationIsBigEnough
        whenLockDurationIsAMultipleOfEpochDuration
        whenPearlmitTransferSucceed
        initTestsAndCreateLock(_lockAmount, WEEK_LONG * uint128(ENDING_EPOCH))
    {
        _lockDuration = uint128(tob.EPOCH_DURATION() * WEEK_LONG * bound(_lockDuration, 1, 4));
        _lockAmount = uint128(
            bound(
                _lockAmount,
                computeMinWeight(VIRTUAL_TOTAL_AMOUNT, tob.MIN_WEIGHT_FACTOR()),
                MAX_USDO_PARTICIPATION_BOUNDARY
            )
        );
        _setupPearlmitApproval();
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.MinRewardTooLow.selector);
        tob.participate(TOLP_TOKEN_ID, MAX_REWARD);
    }

    modifier whenRewardsAreBiggerThanMinReward() {
        _;
    }

    function test_RevertWhen_MagnitudeBiggerThanTheMaxCap(uint128 _lockAmount, uint128 _lockDuration)
        external
        whenNotPaused
        whenLockNotExpired
        whenEpochIsAdvanced
        whenPositionIsActive
        whenLockDurationIsBigEnough
        whenLockDurationIsAMultipleOfEpochDuration
        whenPearlmitTransferSucceed
        whenRewardsAreBiggerThanMinReward
        initTestsAndCreateLockWithNoDurationBound(_lockAmount, uint128(tob.EPOCH_DURATION() * WEEK_LONG * 5))
        setupPearlmitApproval
    {
        // it should revert
        vm.expectRevert(TapiocaOptionBroker.TooLong.selector);
        tob.participate(TOLP_TOKEN_ID, 0);
    }

    modifier whenMagnitudeIsInRange() {
        _;
    }

    uint128 public constant NO_VOTING_POWER_DEPOSIT_AMOUNT = 1;
    uint256 public constant ENDING_EPOCH = 2;

    function test_WhenLockerDoesNotHaveVotingPower()
        external
        whenNotPaused
        whenLockNotExpired
        whenEpochIsAdvanced
        whenPositionIsActive
        whenLockDurationIsBigEnough
        whenLockDurationIsAMultipleOfEpochDuration
        whenPearlmitTransferSucceed
        whenRewardsAreBiggerThanMinReward
        whenMagnitudeIsInRange
    {
        uint128 _lockDuration = uint128(tob.EPOCH_DURATION() * WEEK_LONG * ENDING_EPOCH);
        _initTestsAndCreateLock(uint128(MIN_USDO_PARTICIPATION_BOUNDARY), _lockDuration);
        _setupPearlmitApproval();
        _resetPrank({caller: aliceAddr});

        // it should participate
        whenItShouldParticipate(uint128(MIN_USDO_PARTICIPATION_BOUNDARY), _lockDuration, ENDING_EPOCH, false, false);

        // it should not update cumulative
        (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative) = tob.twAML(1);
        assertEq(
            totalParticipants, 0, "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid totalParticipants"
        );
        assertEq(
            averageMagnitude, 0, "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid averageMagnitude"
        );
        assertEq(totalDeposited, 0, "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid totalDeposited");
        assertEq(cumulative, 0, "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid cumulative");
    }

    function test_WhenLockerHaveVotingPower(uint128 _lockAmount, uint128 _lockDuration)
        external
        whenNotPaused
        whenLockNotExpired
        whenEpochIsAdvanced
        whenPositionIsActive
        whenLockDurationIsBigEnough
        whenLockDurationIsAMultipleOfEpochDuration
        whenPearlmitTransferSucceed
        whenRewardsAreBiggerThanMinReward
        whenMagnitudeIsInRange
        initTestsAndCreateLock(_lockAmount, WEEK_LONG * uint128(ENDING_EPOCH))
        setupPearlmitApproval
    {
        _lockDuration = uint128(tob.EPOCH_DURATION() * WEEK_LONG * bound(_lockDuration, 1, 4));
        _lockAmount = uint128(
            bound(
                _lockAmount,
                computeMinWeight(VIRTUAL_TOTAL_AMOUNT, tob.MIN_WEIGHT_FACTOR()),
                MAX_USDO_PARTICIPATION_BOUNDARY
            )
        );

        _resetPrank({caller: aliceAddr});
        uint256 cumulativeBefore = tob.EPOCH_DURATION();

        uint256 lockTime = WEEK_LONG * ENDING_EPOCH * tob.EPOCH_DURATION();
        // it should participate
        whenItShouldParticipate(_lockAmount, _lockDuration, ENDING_EPOCH, true, true);

        // it should update cumulative
        (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative) =
            tob.twAML(SGL_ASSET_ID);
        assertEq(
            totalParticipants, 1, "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid totalParticipants"
        );

        uint256 expectedMagnitude = computeMagnitude(lockTime, cumulativeBefore);
        assertEq(
            averageMagnitude,
            computeMagnitude(lockTime, cumulativeBefore),
            "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid averageMagnitude"
        ); // it should be (aM * m / participants), aM = 0, participants = 1, so it's magnitude

        assertEq(
            totalDeposited,
            _lockAmount,
            "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid totalDeposited"
        );

        uint256 expectedCumulative = cumulativeBefore + expectedMagnitude;
        assertEq(
            cumulative, expectedCumulative, "TOB_participate::test_WhenLockerDoesNotHaveVotingPower: Invalid cumulative"
        );
    }

    uint256 public constant EXPECTED_DISCOUNT = 500_000;

    function whenItShouldParticipate(
        uint128 _lockAmount,
        uint128 _lockDuration,
        uint256 _endingEpoch,
        bool _hasVotingPower,
        bool _divergenceForce
    ) internal {
        // it should emit Participate
        vm.expectEmit(true, true, false, false);
        emit TapiocaOptionBroker.Participate(tob.epoch(), SGL_ASSET_ID, _lockAmount, 1, 0, 0);
        tob.participate(TOLP_TOKEN_ID, 0);
        // it should save the twAML participation
        (bool hasVotingPower, bool divergenceForce, uint256 averageMagnitude) = tob.participants(1);
        assertEq(hasVotingPower, _hasVotingPower, "TOB_participate::whenItShouldParticipate: Invalid hasVotingPower");
        assertEq(divergenceForce, _divergenceForce, "TOB_participate::whenItShouldParticipate: Invalid divergenceForce");
        if (hasVotingPower) {
            assertGt(averageMagnitude, 0, "TOB_participate::whenItShouldParticipate: Invalid averageMagnitude");
        }
        // it should record the amount for next epoch and decrease it on the last
        assertEq(
            tob.netDepositedForEpoch(tob.epoch() + 1, SGL_ASSET_ID),
            int256(uint256(_lockAmount)),
            "TOB_participate::whenItShouldParticipate: Invalid netDepositedForEpoch for next epoch"
        );
        assertEq(
            tob.netDepositedForEpoch(_endingEpoch + 1, SGL_ASSET_ID),
            -int256(uint256(_lockAmount)),
            "TOB_participate::whenItShouldParticipate: Invalid netDepositedForEpoch for last epoch"
        );
        // it should mint a new oTAP
        assertEq(otap.balanceOf(aliceAddr), 1, "TOB_participate::whenItShouldParticipate: Invalid oTAP balance");
        assertEq(otap.ownerOf(1), aliceAddr, "TOB_participate::whenItShouldParticipate: Invalid oTAP owner");

        (uint128 entry, uint128 expiry, uint128 discount, uint256 tolpId) = otap.options(1);
        LockPosition memory lock = tolp.getLock(TOLP_TOKEN_ID);

        assertEq(entry, block.timestamp, "TOB_participate::whenItShouldParticipate: Invalid entry");
        assertEq(expiry, lock.lockTime + lock.lockDuration, "TOB_participate::whenItShouldParticipate: Invalid expiry");
        assertEq(discount, EXPECTED_DISCOUNT, "TOB_participate::whenItShouldParticipate: Invalid discount");
        assertEq(tolpId, TOLP_TOKEN_ID, "TOB_participate::whenItShouldParticipate: Invalid tOLP ID");
    }
}
