import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import fs from 'fs';
import {
    CONTRIBUTOR_VESTING_TOTAL,
    PRE_SEED_VESTING_TOTAL,
    SEED_VESTING_TOTAL,
} from './registerUsersVesting';

export const vestingInit__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
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

async function tapiocaTask(params: TTapiocaDeployerVmPass<unknown>) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag } = taskArgs;

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

    // TODO: Verification about the balance of each contract matching this number
    await VM.executeMulticall([
        {
            target: preSeedVesting.address,
            allowFailure: false,
            callData: preSeedVesting.interface.encodeFunctionData('init', [
                tapToken.address,
                PRE_SEED_VESTING_TOTAL,
                600, // Initial unlock, in BPS, 6%
            ]),
        },
        {
            target: seedVesting.address,
            allowFailure: false,
            callData: seedVesting.interface.encodeFunctionData('init', [
                tapToken.address,
                SEED_VESTING_TOTAL,
                800, // Initial unlock, in BPS, 8%
            ]),
        },
        {
            target: contributorVesting.address,
            allowFailure: false,
            callData: contributorVesting.interface.encodeFunctionData('init', [
                tapToken.address,
                CONTRIBUTOR_VESTING_TOTAL,
                0, // Initial unlock, in BPS, 0%
            ]),
        },
    ]);
}
