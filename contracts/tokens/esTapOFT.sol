// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/ITapOFT.sol';
import './OFT20/PausableOFT.sol';
import './OFT20/interfaces/ILayerZeroEndpoint.sol';

/// @title Tapioca escrowed TAP token
/// @notice OFT compatible TAP token
contract esTapOFT is PausableOFT {
    // ==========
    // *DATA*
    // ==========

    /// @notice returns the minter address
    /// @dev FeeDistributor contract
    address public minter;

    /// @notice returns the burner address
    /// @dev esTapVesting contract
    address public burner;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice event emitted when a new minter is set
    event MinterUpdated(address indexed _old, address indexed _new);
    /// @notice event emitted when a new burner is set
    event BurnerUpdated(address indexed _old, address indexed _new);
    /// @notice event emitted when new TAP is minted
    event Minted(address indexed _by, address indexed _to, uint256 _amount);
    /// @notice event emitted when new TAP is burned
    event Burned(address indexed _by, address indexed _from, uint256 _amount);

    // ==========
    // * METHODS *
    // ==========
    /// @notice Creates a new TAP OFT type token
    /// @dev The initial supply of 100M is not minted here as we have the wrap method
    /// @param _lzEndpoint the layer zero address endpoint deployed on the current chain

    constructor(
        address _lzEndpoint,
        address _minter,
        address _burner
    ) PausableOFT('Escrowed Tapioca', 'esTAP', _lzEndpoint) {
        require(_lzEndpoint != address(0), 'LZ endpoint not valid');
        require(_minter != address(0), 'Minter not valid');
        require(_burner != address(0), 'Burner not valid');

        minter = _minter;
        burner = _burner;
    }

    ///-- Onwer methods --
    /// @notice sets a new minter address
    /// @dev should be the FeeDistributor address
    /// @param _minter the new address
    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), 'address not valid');
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    /// @notice sets a new burner address
    /// @dev should be the esTapVesting address
    /// @param _burner the new address
    function setBurner(address _burner) external onlyOwner {
        require(_burner != address(0), 'address not valid');
        emit BurnerUpdated(burner, _burner);
        burner = _burner;
    }

    //-- View methods --
    /// @notice returns token's decimals
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    ///-- Write methods --
    /// @notice mints esTAP
    /// @param _for the address to mint for
    /// @param _amount mintable amount
    function mintFor(address _for, uint256 _amount) external {
        require(msg.sender == minter, 'unauthorized');
        _mint(_for, _amount);
        emit Minted(minter, _for, _amount);
    }

    /// @notice burns esTAP
    /// @param _from the address to burn from
    /// @param _amount burnable amount
    function burnFrom(address _from, uint256 _amount) external {
        require(msg.sender == burner, 'unautorized');
        _burn(_from, _amount);
        emit Burned(burner, _from, _amount);
    }
}
