import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { setTapOptionOracle__postDeployLbp } from 'tasks/deployBuilds/postLbpStack/setTapOptionOracle__postDeployLbp';

/**
 * @notice Meant to be called AFTER deployPostLbpStack_1__task AND `tapioca-periph` postLbp task
 *
 * Scripts: Arb
 * - Set Tap Option oracle in ADB
 * - Set USDC as payment token in ADB
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

async function postDeploymentSetup(params: TTapiocaDeployerVmPass<object>) {
    const { hre, VM, taskArgs, isTestnet, isHostChain } = params;
    const { tag } = taskArgs;

    // Setup contracts
    if (isHostChain) {
        await VM.executeMulticall(
            await setTapOptionOracle__postDeployLbp(hre, tag),
        );
    } else {
        console.log(
            '[-] Skipping post LBP2 stack deployment, current chain is not host chain.',
        );
    }
}
