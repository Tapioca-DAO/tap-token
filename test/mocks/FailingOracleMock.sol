// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

contract FailingOracleMock {
    // Get the latest exchange rate
    function get(bytes calldata) public view returns (bool, uint256) {
        return (false, 0);
    }

    // Check the last exchange rate without any state changes
    function peek(bytes calldata) public view returns (bool, uint256) {
        return (false, 0);
    }

    function peekSpot(bytes calldata) public view returns (uint256) {
        return 0;
    }

    function name(bytes calldata) public view returns (string memory) {
        return "Failing Oracle Mock";
    }

    function symbol(bytes calldata) public view returns (string memory) {
        return "Failing Oracle Mock";
    }
}
