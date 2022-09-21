// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice Interface for AureLocker contract
/// @dev https://etherscan.deth.net/address/0x3fa73f1e5d8a792c80f426fc8f84fbf7ce9bbcac#code
interface IAuraLocker {
    function stakingToken() external view returns (address);

    /// @notice Locked tokens cannot be withdrawn for lockDuration and are eligible to receive stakingReward rewards
    /// @dev lock duration = 7*86400*17
    function lock(address _account, uint256 _amount) external;

    /// @notice processes existing locks and relock if opted for
    function processExpiredLocks(bool _relock) external;

    /// notice delegate votes from the sender to `newDelegatee`.
    function delegate(address newDelegatee) external;

    /// notice returns delegated to for account
    function delegates(address account) external view returns (address);
}
