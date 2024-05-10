import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildPostLbpStackPostDepSetup } from 'tasks/deployBuilds/postLbpStack/buildPostLbpStackPostDepSetup';

/**
 * @notice Meant to be called AFTER deployPostLbpStack_1__task AND `tapioca-periph` postLbp task
 * Will load the contracts from the previous deployment and setup the contracts.
 */
export const deployPostLbpStack_2__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        { ..._taskArgs, load: true }, // Load required
        { hre },
        // eslint-disable-next-line @typescript-eslint/no-empty-function, @typescript-eslint/no-unused-vars
        async (_) => {},
        postDeploymentSetup,
    );
};

/**
 * @notice Does the following
 * - Broker claim on AOTAP
 * - Set tapToken in ADB
 * - Set Tap oracle in ADB
 * - Set USDC as payment token in ADB
 */
async function postDeploymentSetup(params: TTapiocaDeployerVmPass<object>) {
    const { hre, VM, taskArgs, isTestnet } = params;
    const { tag } = taskArgs;

    // Setup contracts
    await VM.executeMulticall(await buildPostLbpStackPostDepSetup(hre, tag));
}
