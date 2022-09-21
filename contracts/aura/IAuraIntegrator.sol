// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IAuraIntegrator {
    /// @notice returns the Aura token address
    function auraToken() external returns (IERC20);

    /// @notice called by omniAura to lock newly received Aura
    function triggerLock() external;

    /// @notice delegate votes.
    function triggerDelegate() external;

    /// @notice called by Gelato to re-lock Aura
    function triggerProcessLocked() external;

    /// @notice called by owner to execute any method on the AuraLocker contract
    /// @param data the encoded function data
    function executeAuraLockerFn(bytes memory data) external returns (bool success, bytes memory result);

    /// @notice returns locked Aura balance
    function usedAuraBalance() external view returns (uint256);

    /// @notice returns total Aura balance (locked & unlocked)
    function totalAuraBalance() external view returns (uint256);
}
