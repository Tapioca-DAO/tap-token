// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import '@boringcrypto/boring-solidity/contracts/ERC20.sol';
import './interfaces/IERC20Metadata.sol';

contract Tap is ERC20WithSupply, IERC20Metadata {
    string public name = 'TAP';
    string public symbol = 'TAP';
    uint8 public decimals = 18;

    constructor(uint256 _initialAmount) {
        totalSupply = _initialAmount;
    }
}
