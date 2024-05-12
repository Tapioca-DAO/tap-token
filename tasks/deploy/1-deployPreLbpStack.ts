import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildLTap } from 'tasks/deployBuilds/preLbpStack/buildLTap';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';

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
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    VM.add(await buildLTap(hre, DEPLOYMENT_NAMES.LTAP, [owner], []));
}
