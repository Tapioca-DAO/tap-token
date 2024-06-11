import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';

export const PRE_SEED_VESTING_TOTAL = 3_500_000n * 10n ** 18n; // 3.5m
export const SEED_VESTING_TOTAL = 10n ** 16n * 14_582_575_34n; // 14,582,575.34
export const CONTRIBUTOR_VESTING_TOTAL = 15_000_000n * 10n ** 18n; // 15m

export const registerUsersVesting__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & {
        contributorAddress: string;
        seedFile: string;
        preSeedFile: string;
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
        contributorAddress: string;
        seedFile: string;
        preSeedFile: string;
    }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, contributorAddress, preSeedFile, seedFile } = taskArgs;
    console.log('[+] Registering users for vesting');

    const preSeedVesting = await hre.ethers.getContractAt(
        'Vesting',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.VESTING_EARLY_SUPPORTERS,
            tag,
        ).address,
    );
    const seedVesting = await hre.ethers.getContractAt(
        'Vesting',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.VESTING_SUPPORTERS,
            tag,
        ).address,
    );

    const contributorVesting = await hre.ethers.getContractAt(
        'Vesting',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.VESTING_CONTRIBUTORS,
            tag,
        ).address,
    );
    const tapToken = await hre.ethers.getContractAt(
        'TapToken',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.TAP_TOKEN,
            tag,
        ).address,
    );

    const seedBalance = await tapToken.balanceOf(seedVesting.address);
    if (seedBalance.lt(SEED_VESTING_TOTAL)) {
        throw new Error(
            `[-] Seed vesting contract does not have enough tokens to vest, has ${seedBalance.toBigInt()}, needs ${SEED_VESTING_TOTAL}`,
        );
    }

    const preSeedBalance = await tapToken.balanceOf(preSeedVesting.address);
    if (preSeedBalance.lt(PRE_SEED_VESTING_TOTAL)) {
        throw new Error(
            `[-] PreSeed vesting contract does not have enough tokens to vest, has ${preSeedBalance.toBigInt()}, needs ${PRE_SEED_VESTING_TOTAL}`,
        );
    }

    const contributorBalance = await tapToken.balanceOf(contributorAddress);
    if (contributorBalance.lt(CONTRIBUTOR_VESTING_TOTAL)) {
        throw new Error(
            `[-] Contributor does not have enough tokens to vest, has ${contributorBalance.toBigInt()}, needs ${CONTRIBUTOR_VESTING_TOTAL}`,
        );
    }

    type TData = {
        address: string;
        value: string | number;
    };
    const preSeedData = (await getJsonData(preSeedFile)) as TData[];
    const seedData = (await getJsonData(preSeedFile)) as TData[];

    console.log(
        '[+] Total for preSeed:',
        preSeedData.reduce((acc, data) => acc + Number(data.value), 0),
    );
    console.log(
        '[+] Total for seed:',
        seedData.reduce((acc, data) => acc + Number(data.value), 0),
    );
    console.log('[+] Total for contributor:', CONTRIBUTOR_VESTING_TOTAL);

    await VM.executeMulticall([
        {
            target: preSeedVesting.address,
            allowFailure: false,
            callData: preSeedVesting.interface.encodeFunctionData(
                'registerUsers',
                [
                    preSeedData.map((data) => data.address),
                    preSeedData.map((data) => data.value),
                ],
            ),
        },
        {
            target: seedVesting.address,
            allowFailure: false,
            callData: seedVesting.interface.encodeFunctionData(
                'registerUsers',
                [
                    seedData.map((data) => data.address),
                    seedData.map((data) => data.value),
                ],
            ),
        },
        {
            target: contributorVesting.address,
            allowFailure: false,
            callData: contributorVesting.interface.encodeFunctionData(
                'registerUser',
                [contributorAddress, CONTRIBUTOR_VESTING_TOTAL],
            ),
        },
    ]);
}

async function getJsonData(filePath: string) {
    const fileData = fs.readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(fileData);
    return jsonData;
}
