// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;


import {IOracle} from "tapioca-periph/contracts/interfaces/IOracle.sol";


contract TapOracleMock is IOracle{

    constructor() {}

    function decimals() external view returns (uint8){}
    function get(
        bytes calldata data
    ) external returns (bool success, uint256 rate){
        return (true, 1);
    }

        function peek(
        bytes calldata data
    ) external view returns (bool success, uint256 rate){}

    function peekSpot(bytes calldata data) external view returns (uint256 rate){}

    function symbol(bytes calldata data) external view returns (string memory){}

    function name(bytes calldata data) external view returns (string memory){}
}