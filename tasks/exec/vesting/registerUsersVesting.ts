import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';
import { BigNumber, BigNumberish } from 'ethers';

export const PRE_SEED_VESTING_TOTAL = 3_500_001n * 10n ** 18n; // 3_500_001
export const SEED_VESTING_TOTAL = 10n ** 16n * 14_938_030_34n; // 14,938,030.34
export const CONTRIBUTOR_VESTING_TOTAL = 15_000_000n * 10n ** 18n; // 15m USE THIS FOR PROD
// export const CONTRIBUTOR_VESTING_TOTAL = 5_000_000n * 10n ** 18n;

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
    console.log('[+] Seed balance:', hre.ethers.utils.formatEther(seedBalance));
    if (seedBalance.lt(SEED_VESTING_TOTAL)) {
        throw new Error(
            `[-] Seed vesting contract does not have enough tokens to vest, has ${seedBalance.toBigInt()}, needs ${SEED_VESTING_TOTAL}`,
        );
    }

    const preSeedBalance = await tapToken.balanceOf(preSeedVesting.address);
    console.log(
        '[+] Pre seed balance:',
        hre.ethers.utils.formatEther(preSeedBalance),
    );
    if (preSeedBalance.lt(PRE_SEED_VESTING_TOTAL)) {
        throw new Error(
            `[-] PreSeed vesting contract does not have enough tokens to vest, has ${preSeedBalance.toBigInt()}, needs ${PRE_SEED_VESTING_TOTAL}`,
        );
    }

    const contributorBalance = await tapToken.balanceOf(
        contributorVesting.address,
    );
    console.log(
        '[+] Contributor balance:',
        hre.ethers.utils.formatEther(contributorBalance),
    );
    if (contributorBalance.lt(CONTRIBUTOR_VESTING_TOTAL)) {
        throw new Error(
            `[-] Contributor does not have enough tokens to vest, has ${contributorBalance.toBigInt()}, needs ${CONTRIBUTOR_VESTING_TOTAL}`,
        );
    }

    type TData = {
        address: string;
        value: string;
    };
    type TAggregatedData = {
        address: string;
        value: BigNumber;
    };

    function aggregateValues(data: TData[]): TAggregatedData[] {
        const aggregated: { [key: string]: BigNumber } = {};

        data.forEach((item) => {
            const itemAddress = item.address.toLowerCase().replace(/\s/g, '');
            if (aggregated[itemAddress]) {
                aggregated[itemAddress] = hre.ethers.BigNumber.from(
                    hre.ethers.utils.parseEther(String(item.value)),
                ).add(aggregated[itemAddress]);
            } else {
                aggregated[itemAddress] = hre.ethers.BigNumber.from(
                    hre.ethers.utils.parseEther(String(item.value)),
                );
            }
        });

        return Object.keys(aggregated).map((address) => ({
            address,
            value: aggregated[address],
        }));
    }

    const preSeedDataAggregated: TAggregatedData[] = aggregateValues(
        (await getJsonData(preSeedFile)) as TData[],
    );

    const seedDataAggregated: TAggregatedData[] = aggregateValues(
        (await getJsonData(seedFile)) as TData[],
    );

    console.log(
        '[+] Total for preSeed:',
        hre.ethers.utils.formatEther(
            preSeedDataAggregated.reduce(
                (acc, data) => acc + data.value.toBigInt(),
                0n,
            ),
        ),
    );
    console.log(
        '[+] Total for seed:',
        hre.ethers.utils.formatEther(
            seedDataAggregated.reduce(
                (acc, data) => acc + data.value.toBigInt(),
                0n,
            ),
        ),
    );
    console.log(
        '[+] Total for contributor:',
        hre.ethers.utils.formatEther(CONTRIBUTOR_VESTING_TOTAL),
    );

    const registerUsers = async (
        targetContract: string,
        addresses: string[],
        values: BigNumber[],
    ) => {
        const batchedAddresses = splitIntoBatches(addresses, 50);
        const batchedValues = splitIntoBatches(values, 50);

        for (let i = 0; i < batchedAddresses.length; i++) {
            await VM.executeMulticall([
                {
                    target: targetContract,
                    allowFailure: false,
                    callData: preSeedVesting.interface.encodeFunctionData(
                        'registerUsers',
                        [batchedAddresses[i], batchedValues[i]],
                    ),
                },
            ]);
        }
    };

    const filterPreSeed = async (data: TAggregatedData) => {
        if ((await preSeedVesting.users(data.address)).amount.gt(0)) {
            return false;
        }
        return data;
    };

    const filterSeed = async (data: TAggregatedData) => {
        if ((await seedVesting.users(data.address)).amount.gt(0)) {
            return false;
        }
        return data;
    };

    const preSeedToRegister = (
        await Promise.all(preSeedDataAggregated.map(filterPreSeed))
    ).filter((e) => e);

    const seedToRegister = (
        await Promise.all(seedDataAggregated.map(filterSeed))
    ).filter((e) => e);

    console.log('[+] PreSeed to register:', preSeedToRegister.length);
    await registerUsers(
        preSeedVesting.address,
        preSeedToRegister.map((data) => (data as TAggregatedData).address),
        preSeedToRegister.map((data) => (data as TAggregatedData).value),
    );

    console.log('[+] Seed to register:', seedToRegister.length);
    await registerUsers(
        seedVesting.address,
        seedToRegister.map((data) => (data as TAggregatedData).address),
        seedToRegister.map((data) => (data as TAggregatedData).value),
    );

    console.log('[+] Registering contributor');
    await VM.executeMulticall([
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

function splitIntoBatches<T>(array: T[], batchSize: number): T[][] {
    const batches: T[][] = [];

    for (let i = 0; i < array.length; i += batchSize) {
        const batch = array.slice(i, i + batchSize);
        batches.push(batch);
    }

    return batches;
}
