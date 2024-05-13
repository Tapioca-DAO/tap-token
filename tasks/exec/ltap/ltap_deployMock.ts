import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import { buildLTapMock } from 'tasks/deployBuilds/mocks/buildLtapMock';

export const ltap__deployMock__task = async (
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

    if (!isTestnet) {
        throw new Error('[+] This task is only for testnet');
    }

    VM.add(await buildLTapMock(hre, DEPLOYMENT_NAMES.LTAP, [owner, owner], []));
}
