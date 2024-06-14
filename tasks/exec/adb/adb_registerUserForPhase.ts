import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';
import path from 'path';
import { BigNumberish } from 'ethers';

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
    const amounts: BigNumberish[] = [];
    jsonData.forEach((data) => {
        users.push(data.user);
        amounts.push(data.amount);
    });

    // users.push(
    //     '0x22076fba2ea9650a028Aa499d0444c4Aa9aF1Bf8',
    //     '0x763D405278D7532548fb2804dD6A7d7943213b6D',
    //     '0xC3aef76B87539387B84CFfDA1b93A674f126deb0',
    //     '0x86C73B2E0CB8E4b1272f8DAaaca0e7e8B6143be6',
    //     '0xEAF9f533871B07B151883908B4Fb6eeF4b51A95F',
    //     '0xFc78700591Ac71c96102A4f9bD8Fc97D663355CC',
    // );
    // amounts.push(
    //     hre.ethers.utils.parseEther('1000'),
    //     hre.ethers.utils.parseEther('1000'),
    //     hre.ethers.utils.parseEther('1000'),
    //     hre.ethers.utils.parseEther('1000'),
    //     hre.ethers.utils.parseEther('1000'),
    //     hre.ethers.utils.parseEther('1000'),
    // );

    const batchUsers = splitIntoBatches(users, 200);
    const batchAmounts = splitIntoBatches(amounts, 200);

    for (let i = 0; i < batchUsers.length; i++) {
        const userSlice = batchUsers[i];
        const amountSlice = batchAmounts[i];

        await VM.executeMulticall([
            {
                target: adb.address,
                allowFailure: false,
                callData: adb.interface.encodeFunctionData(
                    'registerUsersForPhase',
                    [phase, userSlice, amountSlice],
                ),
            },
        ]);
    }
}

async function getJsonData(filePath: string) {
    const fileData = fs.readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(fileData);
    return jsonData;
}

function splitIntoBatches<T>(array: T[], batchSize: number): T[][] {
    const batches: T[][] = [];

    for (let i = 0; i < array.length; i += batchSize) {
        const batch = array.slice(i, i + batchSize);
        batches.push(batch);
    }

    return batches;
}
