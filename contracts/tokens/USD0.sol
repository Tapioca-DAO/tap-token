// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/ILayerZeroEndpoint.sol';
import './OFT20/PausableOFT.sol';

contract USD0 is PausableOFT {
    /// @notice addresses allowed to mint USD0
    mapping(address => bool) allowedMinter;
    /// @notice addresses allowed to burn USD0
    mapping(address => bool) allowedBurner;

    /// @notice creates USDO0 OFT
    /// @param _lzEndpoint LayerZero endpoint
    constructor(address _lzEndpoint) PausableOFT('USD0', 'UDS0', _lzEndpoint) {
        allowedMinter[msg.sender] = true;
        allowedBurner[msg.sender] = true;
    }

    //-- View methods --
    /// @notice returns token's decimals
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    //-- Write methods --
    /// @notice mints USD0
    /// @param _to receiver address
    /// @param _amount the amount to mint
    function mint(address _to, uint256 _amount) external {
        require(allowedMinter[msg.sender], 'unauthorized');
        _mint(_to, _amount);
    }

    /// @notice burns USD0
    /// @param _from address to burn from
    /// @param _amount the amount to burn
    function burn(address _from, uint256 _amount) external {
        require(allowedBurner[msg.sender], 'unauthorized');
        _burn(_from, _amount);
    }

    //-- Owner methods --
    /// @notice sets/unsets address as minter
    /// @param _for role receiver
    /// @param _status true/false
    function setMinterStatus(address _for, bool _status) external onlyOwner {
        allowedMinter[_for] = _status;
    }

    /// @notice sets/unsets address as burner
    /// @param _for role receiver
    /// @param _status true/false
    function setBurnerStatus(address _for, bool _status) external onlyOwner {
        allowedBurner[_for] = _status;
    }
}
