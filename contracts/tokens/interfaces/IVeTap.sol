// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVeTap {
    function create_lock_for(
        address _addr,
        uint256 _value,
        uint256 _unlock_time
    ) external;

    function increase_amount_for(address _addr, uint256 _value) external;
}
