import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';

export const adb_setMerkleRoots__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & { rootsFile: string },
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
    params: TTapiocaDeployerVmPass<{ rootsFile: string }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, rootsFile } = taskArgs;
    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.AIRDROP_BROKER,
            tag,
        ).address,
    );

    const jsonData = (await getJsonData(rootsFile)) as string[];
    if (jsonData.length !== 4) {
        throw new Error('[-] Invalid number of roots, require 4');
    }
    const data = jsonData.map((e) => '0x' + e) as [
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

async function getJsonData(filePath: string) {
    const fileData = fs.readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(fileData);
    return jsonData;
}
