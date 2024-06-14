import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';

export const adb_setMerkleRoots__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & {
        role0: string;
        role1: string;
        role2: string;
        role3: string;
    },
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
    params: TTapiocaDeployerVmPass<{
        role0: string;
        role1: string;
        role2: string;
        role3: string;
    }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, role0, role1, role2, role3 } = taskArgs;
    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.AIRDROP_BROKER,
            tag,
        ).address,
    );

    const data = [role0, role1, role2, role3].map((e) => '0x' + e) as [
        string,
        string,
        string,
        string,
    ];

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
