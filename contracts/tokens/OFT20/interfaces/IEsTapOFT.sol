// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEsTapOFT {
    /// @notice mints esTAP
    /// @param _for the address to mint for
    /// @param _amount mintable amount
    function mintFor(address _for, uint256 _amount) external;

    /// @notice burns esTAP
    /// @param _from the address to burn from
    /// @param _amount burnable amount
    function burnFrom(address _from, uint256 _amount) external;
}
