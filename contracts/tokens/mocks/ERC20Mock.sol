// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@boringcrypto/boring-solidity/contracts/ERC20.sol";

contract ERC20Mock is ERC20WithSupply {
    string public name;
    string public symbol;
    uint8 public decimals;
    address public owner;

    mapping(address => uint256) public mintedAt;
    uint256 public constant MINT_WINDOW = 24 hours;
    uint256 public mintLimit;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialAmount,
        uint8 _decimals,
        address _owner
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialAmount;
        decimals = _decimals;
        mintLimit = 1000 * (10 ** _decimals);
        owner = _owner;
    }

    function mintTo(address _to, uint256 _amount) external {
        require(msg.sender == owner, "ERC20Mock: only owner");
        _mint(_to, _amount);
    }

    function updateMintLimit(uint256 _newVal) external {
        require(msg.sender == owner, "UNAUTHORIZED");
        mintLimit = _newVal;
    }

    function freeMint(uint256 _val) external {
        require(_val <= mintLimit, "ERC20Mock: amount too big");
        require(
            mintedAt[msg.sender] + MINT_WINDOW <= block.timestamp,
            "ERC20Mock: too early"
        );

        mintedAt[msg.sender] = block.timestamp;

        _mint(msg.sender, _val);
    }
}
