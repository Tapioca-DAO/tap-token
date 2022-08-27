// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice Fee distributor interface
interface IFeeDistributor {
    /// @notice claims rewards
    /// @param addr reciever
    /// @param lock if true will lock rewards into the veTap contract
    function claim(address addr, bool lock) external returns (uint256);
}
