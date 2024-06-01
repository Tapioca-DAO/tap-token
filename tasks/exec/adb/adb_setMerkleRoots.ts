import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';

export const adb_setMerkleRoots__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & { roots: string[] },
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        // eslint-disable-next-line @typescript-eslint/no-empty-function
        async () => {},
        tapiocaTask,
    );
};

async function tapiocaTask(
    params: TTapiocaDeployerVmPass<{ roots: string[] }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, roots } = taskArgs;
    if (roots.length !== 4) {
        throw new Error('[-] Invalid number of roots, require 4');
    }
    const data = roots.map((e) => '0x' + e) as [string, string, string, string];

    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.AIRDROP_BROKER,
            tag,
        ).address,
    );

    // await adb.setPhase2MerkleRoots(roots as [string, string, string, string]);
    await VM.executeMulticall([
        {
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setPhase2MerkleRoots', [
                data,
            ]),
        },
    ]);
}
