// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Liquidity gauge  interface
interface ILiquidityGauge {
    function deposit(uint256 amount, address user) external;
}
