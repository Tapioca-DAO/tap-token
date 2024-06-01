import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';
import path from 'path';

export const adb_setPhase2Roots__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & { phase: string; userFile: string },
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
    params: TTapiocaDeployerVmPass<{ phase: string; userFile: string }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, userFile, phase } = taskArgs;

    if (phase !== '1' && phase !== '4') {
        throw new Error('[-] Invalid phase, only 1 and 4 are supported');
    }
    // get the json data in the userFile
    const jsonData = (await getJsonData(userFile)) as {
        user: string;
        amount: string;
    }[];

    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.AIRDROP_BROKER,
            tag,
        ).address,
    );

    const users: string[] = [];
    const amounts: string[] = [];
    jsonData.forEach((data) => {
        users.push(data.user);
        amounts.push(data.amount);
    });

    await VM.executeMulticall([
        {
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData(
                'registerUsersForPhase',
                [phase, users, amounts],
            ),
        },
    ]);
}

async function getJsonData(filePath: string) {
    const fileData = fs.readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(fileData);
    return jsonData;
}
