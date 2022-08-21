// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './vyper/interfaces/IGaugeController.sol';
import './gauges/interfaces/ILiquidityGauge.sol';
import './tokens/interfaces/ITapOFT.sol';

//TODO: update pushRewards with timestamp and retain pushedInWeek
contract GaugeDistributor is Ownable, ReentrancyGuard {
    // ==========
    // *DATA*
    // ==========

    ///@notice the reward token that's being added to liquidity gauges
    address public token;
    ///@notice the GaugeController address
    address public controller;

    // ==========
    // *EVENTS*
    // ==========

    ///@notice event emitted when rewards are pushed to a gauge
    event PushedRewards(address indexed gauge, address indexed sender, uint256 pushed);

    // ==========
    // *METHODS*
    // ==========
    /// @notice creates a new GaugeDistributor
    /// @param _token the reward token address
    /// @param _controller the GaugeController address
    constructor(address _token, address _controller) {
        require(_token != address(0), 'token not valid');
        require(_controller != address(0), 'controller not valid');

        token = _token;
        controller = _controller;
    }

    ///-- View methods --
    /// @notice returns the available rewards for a gauge
    /// @param gaugeAddr the registered gauge address
    function availableRewards(address gaugeAddr) external view returns (uint256) {
        return _extractableRewards(gaugeAddr);
    }

    ///-- Owner methods --
    // @dev renounce ownership override to avoid losing contract's ownership
    function renounceOwnership() public pure override {
        revert('unauthorized');
    }

    /// @notice pushes new rewards to a gauge
    /// @param gaugeAddr the registered gauge address
    function pushRewards(address gaugeAddr) external onlyOwner returns (uint256) {
        return _pushRewards(gaugeAddr);
    }

    /// @notice pushes new rewards to multiple gauges
    /// @param gaugeAddresses the registered gauge addresses
    function pushRewardsToMany(address[] calldata gaugeAddresses) external onlyOwner {
        for (uint256 i = 0; i < gaugeAddresses.length; i++) {
            if (gaugeAddresses[i] != address(0)) {
                _pushRewards(gaugeAddresses[i]);
            }
        }
    }

    ///-- Private methods --
    function _extractableRewards(address gaugeAddr) private view returns (uint256) {
        int128 gaugeType = IGaugeController(controller).gauge_types(gaugeAddr);
        if (gaugeType < 0) return 0;

        uint256 weight = IGaugeController(controller).gauge_relative_weight(gaugeAddr);
        uint256 available = ITapOFT(token).balanceOf(token);

        return (weight * available) / 10**18;
    }

    function _pushRewards(address gaugeAddr) private returns (uint256) {
        uint256 toPush = _extractableRewards(gaugeAddr);
        if (toPush > 0) {
            ITapOFT(token).extractTAP(address(this), toPush);
            ITapOFT(token).approve(gaugeAddr, toPush);
            ILiquidityGauge(gaugeAddr).addRewards(toPush);
            emit PushedRewards(gaugeAddr, msg.sender, toPush);
        }
        return toPush;
    }
}
