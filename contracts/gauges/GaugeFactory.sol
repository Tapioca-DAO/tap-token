// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/proxy/Clones.sol';
import './interfaces/ILiquidityGauge.sol';

///@notice Allows creating Liquidity gauges with a low cost
///@dev Anyone can create gauges, but only some are added to the GaugeController
contract GaugeFactory {
    // ==========
    // *DATA*
    // ==========

    /// @notice initial gauge reference that's being cloned
    address public gaugeReference;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice emitted when a new gauge is created
    event GaugeCreated(address indexed _owner, address indexed _gauge);

    // ==========
    // * METHODS *
    // ==========

    ///@notice creates a new GaugeFactory contract
    ///@param _gaugeReference an existing gauge address
    constructor(address _gaugeReference) {
        require(_gaugeReference != address(0), 'gauge not valid');
        gaugeReference = _gaugeReference;
    }

    /// @notice clones the gauge reference and initializes it with the new values
    /// @dev the owner of the new gauge will be msg.sender
    /// @param _token deposit token address
    /// @param _reward reward token address
    /// @param _distributor the GaugeDistributor address
    function createGauge(address _token, address _reward, address _distributor) public returns (address newGauge) {
        newGauge = Clones.clone(gaugeReference);

        ILiquidityGauge(newGauge).init(_token, _reward, msg.sender, _distributor);
        emit GaugeCreated(msg.sender, newGauge);
    }
}
