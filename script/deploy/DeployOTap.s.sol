// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {IMulticall3} from "contracts/interfaces/IMulticall3.sol";
import {TapiocaDeployer} from "tapioca-periph/utils/TapiocaDeployer.sol";
import {OTAP} from "contracts/options/oTAP.sol";

// solhint-disable-next-line
import "forge-std/Script.sol";

contract DeployOTap is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        bytes32 DEPLOY_SALT = keccak256(abi.encode(vm.envString("DEPLOY_SALT")));

        // Load deployment contracts
        TapiocaDeployer tapiocaDeployer_ = TapiocaDeployer(vm.envAddress("TAPIOCA_DEPLOYER"));
        IMulticall3 multicall_ = IMulticall3(vm.envAddress("MULTICALL3"));

        // deployment bytecode
        bytes memory otapDepBytecode_ = getOtapDeploymentBytecode(DEPLOY_SALT, getOtapBytecode());

        // Pre compute addresses
        address computedOtapAddress =
            tapiocaDeployer_.computeAddress(DEPLOY_SALT, keccak256(getOtapBytecode()), address(multicall_));
        console.log("Computed OTap address: %s", computedOtapAddress);

        // Prepare the multicall deployment
        IMulticall3.Call3[] memory calls_ = new IMulticall3.Call3[](1);
        calls_[0] = IMulticall3.Call3({
            target: address(tapiocaDeployer_), // The target address
            callData: otapDepBytecode_, // The call data (encoded function + arguments, if any)
            allowFailure: false
        });

        // Send the multicall Tx
        vm.startBroadcast(deployerPrivateKey);
        multicall_.aggregate3(calls_);
        vm.stopBroadcast();

        // Verify on etherscan
    }

    /// @dev Might not be needed? Use `--verify` on shell cmd.
    function verify(address _target) internal {
        string[] memory inputs = new string[](6);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(_target);
        inputs[3] = "OTAP";
        inputs[4] = "--chain";
        inputs[5] = vm.envString("CHAIN_NAME");
        bytes memory res = vm.ffi(inputs);
        string memory output = abi.decode(res, (string));
        console.log(output);
    }

    function getOtapDeploymentBytecode(bytes32 _salt, bytes memory _bytecode) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(TapiocaDeployer.deploy.selector, 0, _salt, _bytecode, "OTap");
    }

    /// @dev No need to encodePacked, no constructor arguments.
    function encodeTapiocaDeployerCall() internal pure returns (bytes memory) {
        return getOtapBytecode();
    }

    function getOtapBytecode() internal pure returns (bytes memory) {
        return type(OTAP).creationCode;
    }
}
