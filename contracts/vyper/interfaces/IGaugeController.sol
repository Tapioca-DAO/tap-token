// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable func-name-mixedcase

/// @notice Gauge controller interface
interface IGaugeController {
    /// @notice returns gauge relative weight
    /// @param addr gauge address
    function gauge_relative_weight(address addr) external view returns (uint256);

    /// @notice updates gauge relative weight
    /// @param addr gauge address
    function gauge_relative_weight_write(address addr) external returns (uint256);

    ///@notice returns the gauge type
    ///@param addr the gauge address
    function gauge_types(address addr) external view returns (int128);
}
