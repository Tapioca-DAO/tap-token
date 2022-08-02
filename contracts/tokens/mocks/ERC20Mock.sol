// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@boringcrypto/boring-solidity/contracts/ERC20.sol';

contract ERC20Mock is ERC20WithSupply {
    constructor(uint256 _initialAmount) {
        totalSupply = _initialAmount;
    }

    function freeMint(uint256 _val) public {
        _mint(msg.sender, _val);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function name() external pure returns (string memory) {
        return 'Test Token';
    }

    function symbol() external pure returns (string memory) {
        return 'TST';
    }
}
