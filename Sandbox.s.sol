// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import "forge-std/Script.sol";

contract ForgeSandbox is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        vm.stopBroadcast();
    }
}
