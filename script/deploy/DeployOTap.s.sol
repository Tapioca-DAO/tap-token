// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {OTAP} from "@contracts/options/oTAP.sol";

// solhint-disable-next-line
import "forge-std/Script.sol";

contract DeployOTap is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OTAP oTAP = new OTAP();
        // solhint-disable-next-line
        console.log(address(oTAP));

        vm.stopBroadcast();
    }
}
