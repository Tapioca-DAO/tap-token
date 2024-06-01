import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { addTapTokenContractsVM } from './2-1-deployPostLbpStack';
import { setLzPeer__task } from 'tapioca-sdk';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';

/**
 * @notice Meant to be called AFTER deployPostLbpStack_1__task
 *
 * Deploys: Eth
 * - TapToken
 *
 * Post deploy: Arb, Eth
 * - Set LZ peer
 */
export const deploySideChainPostLbpStack_1__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        {
            hre,
        },
        tapiocaDeployTask,
        linkTapContract,
    );
};

async function tapiocaDeployTask(params: TTapiocaDeployerVmPass<object>) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    // Build contracts
    await addTapTokenContractsVM({
        hre,
        tag,
        owner,
        VM,
        lzEndpointAddress: chainInfo.address,
        isTestnet,
        chainInfo,
    });
}

async function linkTapContract(params: TTapiocaDeployerVmPass<object>) {
    // Settings
    const { hre, taskArgs } = params;

    await setLzPeer__task(
        { ...taskArgs, targetName: DEPLOYMENT_NAMES.TAP_TOKEN },
        hre,
    );
}
