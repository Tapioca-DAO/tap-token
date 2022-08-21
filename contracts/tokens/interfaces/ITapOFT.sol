// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITapOFT {
    function extractTAP(address to, uint256 value) external;

    function approve(address to, uint256 value) external;

    function balanceOf(address user) external view returns (uint256);
}
