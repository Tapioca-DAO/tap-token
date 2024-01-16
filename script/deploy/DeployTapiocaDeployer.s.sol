// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {TapiocaDeployer} from "@contracts/utils/TapiocaDeployer.sol";

// solhint-disable-next-line
import "forge-std/Script.sol";

contract DeployTapiocaDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TapiocaDeployer tapiocaDeployer_ = new TapiocaDeployer();

        console.log(address(tapiocaDeployer_));

        vm.stopBroadcast();
    }
}
