// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './OFT20/PausableOFT.sol';
import './interfaces/ILayerZeroEndpoint.sol';

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../aura/IAuraIntegrator.sol';

/// @title omniAura contract
/// @notice OFT version of Aura
/// @dev Contract receives Aura which is sent to AuraIntegrator and mints back oAura
contract omniAura is PausableOFT {
    using SafeERC20 for IERC20;
    // ==========
    // *DATA*
    // ==========

    IERC20 public immutable auraToken;
    IAuraIntegrator public auraIntegrator;

    // ==========
    // *EVENTS*
    // ==========

    event AuraIntegratorUpdated(address indexed oldAddr, address indexed newAddr);
    event Minted(address indexed from, address indexed to, uint256 amount, bool status);

    constructor(address _lzEndpoint, IAuraIntegrator _auraIntegrator) PausableOFT('omniAura', 'oAura', _lzEndpoint) {
        require(_lzEndpoint != address(0), 'oAura: LZ endpoint not valid');

        auraIntegrator = _auraIntegrator;
        auraToken = IERC20(_auraIntegrator.auraToken());
    }

    // ==========
    // *METHODS*
    // ==========

    //-- View methods --
    /// @notice returns token's decimals
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    ///-- Onwer methods --
    function setIntegrator(IAuraIntegrator _integrator) external onlyOwner {
        emit AuraIntegratorUpdated(address(auraIntegrator), address(_integrator));
        auraIntegrator = _integrator;
    }

    //-- Write methods --
    /// @notice mints oAura to sender
    /// @param amount the amount to mint
    function wrap(uint256 amount) external whenNotPaused returns (bool status) {
        status = _mint(msg.sender, msg.sender, amount);
    }

    /// @notice mints oAura to recipient
    /// @dev extracts Aura from sender and sends it to
    /// @param amount the amount to mint
    /// @param recipient receiver of oAura token
    function wrapFor(uint256 amount, address recipient) external whenNotPaused returns (bool status) {
        status = _mint(msg.sender, recipient, amount);
    }

    //-- Private methods --
    function _mint(
        address from,
        address recipient,
        uint256 amount
    ) private returns (bool status) {
        auraToken.safeTransferFrom(from, address(auraIntegrator), amount);
        auraIntegrator.triggerLock();

        uint256 recipientBalanceBefore = balanceOf(recipient);
        _mint(recipient, amount);
        uint256 recipientBalanceAfter = balanceOf(recipient);

        status = recipientBalanceAfter - recipientBalanceBefore == amount;
        emit Minted(from, recipient, amount, status);
    }
}
