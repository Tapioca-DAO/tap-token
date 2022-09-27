// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/IOFT.sol';
import './interfaces/IoTapOFT.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract TapiocaOptions is Ownable {
    using SafeERC20 for IERC20;
    // ==========
    // *DATA*
    // ==========
    IOFT public immutable tap;
    IoTapOFT public immutable oTap;

    uint256 public totalTap;

    // ==========
    // *EVENTS*
    // ==========
    event RewardsQueued(address indexed _from, uint256 _amount);

    constructor(IOFT _tap, IoTapOFT _oTap) {
        tap = _tap;
        oTap = _oTap;
    }

    //sign (get oTap)
    //exercise (get Tap if conditions are met)

    function sign(address _for, uint256 _amount) external returns (uint256 id) {
        require(tap.transferFrom(msg.sender, address(this), _amount), 'transfer failed');
        return oTap.claim(_for, _amount, _constructOracleData());
    }

    function exercise(uint256 _id) external returns (uint256 amount) {}

    function _constructOracleData() private pure returns (bytes memory _data) {
        _data = abi.encode(1, 1); //todo add the right data
    }

    function queueRewards(uint256 _amount) external {
        require(tap.transferFrom(msg.sender, address(this), _amount), 'transfer failed');
        totalTap += _amount;
        emit RewardsQueued(msg.sender, _amount);
    }
}
