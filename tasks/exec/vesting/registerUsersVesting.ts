import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';
import { BigNumberish } from 'ethers';

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

    const contributorBalance = await tapToken.balanceOf(contributorAddress);
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
        value: bigint;
    };

    function aggregateValues(data: TData[]): TAggregatedData[] {
        const aggregated: { [key: string]: number } = {};

        data.forEach((item) => {
            if (aggregated[item.address]) {
                aggregated[item.address] += Number(item.value);
            } else {
                aggregated[item.address] = Number(item.value);
            }
        });

        return Object.keys(aggregated).map((address) => ({
            address,
            // Cast to BigInt and convert to 1e18. Uses 10^10 as a multiplier to avoid floating point errors
            value: BigInt(Number(aggregated[address]) * 10 ** 10) * 10n ** 8n,
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
            preSeedDataAggregated.reduce((acc, data) => acc + data.value, 0n),
        ),
    );
    console.log(
        '[+] Total for seed:',
        hre.ethers.utils.formatEther(
            seedDataAggregated.reduce((acc, data) => acc + data.value, 0n),
        ),
    );
    console.log(
        '[+] Total for contributor:',
        hre.ethers.utils.formatEther(CONTRIBUTOR_VESTING_TOTAL),
    );

    await VM.executeMulticall([
        {
            target: preSeedVesting.address,
            allowFailure: false,
            callData: preSeedVesting.interface.encodeFunctionData(
                'registerUsers',
                [
                    preSeedDataAggregated.map((data) => data.address),
                    preSeedDataAggregated.map((data) => data.value),
                ],
            ),
        },
        {
            target: seedVesting.address,
            allowFailure: false,
            callData: seedVesting.interface.encodeFunctionData(
                'registerUsers',
                [
                    seedDataAggregated.map((data) => data.address),
                    seedDataAggregated.map((data) => data.value),
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
