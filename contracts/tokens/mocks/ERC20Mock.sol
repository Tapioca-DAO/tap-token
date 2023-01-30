// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import '@boringcrypto/boring-solidity/contracts/ERC20.sol';

contract ERC20Mock is ERC20WithSupply {
    uint8 public decimals;

    constructor(uint256 _initialAmount, uint256 _decimals) {
        totalSupply = _initialAmount;
        decimals = uint8(_decimals);
    }

    function freeMint(uint256 _val) public {
        _mint(msg.sender, _val);
    }

    function name() external pure returns (string memory) {
        return 'Test Token';
    }

    function symbol() external pure returns (string memory) {
        return 'TST';
    }
}
