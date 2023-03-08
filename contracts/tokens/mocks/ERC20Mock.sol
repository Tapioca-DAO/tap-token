// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;
import "@boringcrypto/boring-solidity/contracts/ERC20.sol";

contract ERC20Mock is ERC20WithSupply {
    uint8 public decimals;
    string public name;
    string public symbol;

    address public immutable owner = msg.sender;

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

    function mintTo(address _to, uint256 _amount) external {
        require(msg.sender == owner, "ERC20Mock: only owner");
        _mint(_to, _amount);
    }

    function freeMint(uint256 _val) public {
        if (msg.sender != owner) {
            require(_val < 100_000_000 * 1e18, "ERC20Mock: too much");
        }
        _mint(msg.sender, _val);
    }
}
