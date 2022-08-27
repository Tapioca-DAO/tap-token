// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Liquidity gauge interface
interface ILiquidityGauge {
    function init(
        address _token,
        address _reward,
        address _owner,
        address _distributor
    ) external;

    function addRewards(uint256 _amount) external;

    function deposit(uint256 _amount) external;
}
