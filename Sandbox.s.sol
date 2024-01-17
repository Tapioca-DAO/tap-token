// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import "forge-std/Script.sol";

contract ForgeSandbox is Script {
    function run() external {
        uint256 deployerPrivateKey_ = vm.envUint("PRIVATE_KEY");
        address caller_ = vm.addr(deployerPrivateKey_);

        vm.startBroadcast(deployerPrivateKey_);

        vm.stopBroadcast();
    }
}
