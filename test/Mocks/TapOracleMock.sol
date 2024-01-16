// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;


import {TapOracle} from "tapioca-periph/contracts/oracle/implementations/Arbitrum/TapOracle.sol";
import {IOracle} from "tapioca-periph/contracts/interfaces/IOracle.sol";


contract TapOracleMock is IOracle{

    constructor() {}


    function get(
        bytes calldata data
    ) external returns (bool success, uint256 rate){
        return (true, 1);
    }
}