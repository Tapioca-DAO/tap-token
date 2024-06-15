import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildLTap } from 'tasks/deployBuilds/preLbpStack/buildLTap';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';

/**
 * @notice Called after periph perLbp task
 *
 * Deploys: Arb
 * - LTAP
 */
export const deployPreLbpStack__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre, staticSimulation: false },
        tapiocaDeployTask,
    );
};

async function tapiocaDeployTask(params: TTapiocaDeployerVmPass<object>) {
    const {
        hre,
        VM,
        tapiocaMulticallAddr,
        taskArgs,
        isTestnet,
        isHostChain,
        isSideChain,
    } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    if (isHostChain) {
        VM.add(await buildLTap(hre, DEPLOYMENT_NAMES.LTAP, [owner, owner], []));
    } else {
        console.log(
            '[-] Skipping LTAP deployment, current chain is not host chain.',
        );
    }
}
