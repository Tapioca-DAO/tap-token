// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {TapiocaDeployer} from "@contracts/utils/TapiocaDeployer.sol";

// solhint-disable-next-line
import "generated/deployer/DeployerFunctions.g.sol";
import "forge-deploy/DeployScript.sol";

contract DeployTapiocaDeployer is DeployScript {
    using DeployerFunctions for Deployer;

    function deploy() external returns (TapiocaDeployer) {
        return deployer.deploy_TapiocaDeployer("TapiocaDeployer");
    }
}
