// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import '@boringcrypto/boring-solidity/contracts/ERC20.sol';

contract ERC20Mock is ERC20WithSupply {
    uint8 public decimals;
    string public name;
    string public symbol;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialAmount,
        uint256 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialAmount;
        decimals = uint8(_decimals);
    }

    function freeMint(uint256 _val) public {
        _mint(msg.sender, _val);
    }
}
