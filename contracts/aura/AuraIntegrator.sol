// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import './IAuraIntegrator.sol';
import './IAuraLocker.sol';

contract AuraIntegrator is IAuraIntegrator, Ownable {
    // ==========
    // *DATA*
    // ==========

    uint256 public override usedAuraBalance;
    uint256 public override totalAuraBalance;
    IERC20 public override auraToken;
    IAuraLocker public auraLocker;

    address public delegatedTo;

    // ==========
    // *EVENTS*
    // ==========

    event AuraLockerUpdated(address indexed oldVal, address indexed newVal);
    event DelegateeUpdated(address indexed oldVal, address indexed newVal);

    constructor(IAuraLocker _locker, address _delegatedTo) {
        auraLocker = _locker;
        auraToken = IERC20(_locker.stakingToken());
        delegatedTo = _delegatedTo;
    }

    // ==========
    // *METHODS*
    // ==========

    ///-- Write methods --
    /// @notice called by owner to execute any method on the AuraLocker contract
    /// @param data the encoded function data
    function executeAuraLockerFn(bytes memory data) external override onlyOwner returns (bool success, bytes memory result) {
        (success, result) = address(auraLocker).call(data);
    }

    /// @notice lock available balance of Aura
    function triggerLock() external override {
        uint256 availableBalance = auraToken.balanceOf(address(this));
        require(availableBalance > 0, 'AI: nothing to lock');
        _lock(availableBalance);
        _delegate();
    }

    /// @notice called by Gelato to re-lock Aura
    function triggerProcessLocked() external override {
        auraLocker.processExpiredLocks(true);
        _delegate();
    }

    /// @notice delegate votes to `delegatedTo`.
    function triggerDelegate() external {
        _delegate();
    }

    ///-- Owner methods --
    /// @notice update AuraLocker contract address
    /// @param _locker the new locker address
    function setAuraLocker(IAuraLocker _locker) external onlyOwner {
        emit AuraLockerUpdated(address(auraLocker), address(_locker));
        auraLocker = _locker;
    }

    /// @notice sets delegatee
    /// @param _delegateTo the new delegatee address
    function setDelegatee(address _delegateTo) external onlyOwner {
        emit DelegateeUpdated(delegatedTo, _delegateTo);
        delegatedTo = _delegateTo;
    }

    ///-- Private methods --
    function _lock(uint256 amount) private {
        auraToken.approve(address(auraLocker), amount);
        auraLocker.lock(address(this), amount);
    }

    function _delegate() private {
        address crtDelegate = auraLocker.delegates(address(this));

        if (crtDelegate != delegatedTo) {
            //delegate voting power to EOA/external contract for Aura's future integrations
            //to support Snapshot or other voting systems
            auraLocker.delegate(delegatedTo);
        }
    }
}
