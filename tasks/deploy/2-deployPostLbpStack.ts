import { ELZChainID, TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTapToken } from 'tasks/deployBuilds/finalStack/options/tapToken/buildTapToken';
import { buildADB } from 'tasks/deployBuilds/postLbpStack/airdrop/buildADB';
import { buildAOTAP } from 'tasks/deployBuilds/postLbpStack/airdrop/buildAOTAP';
import {
    buildPostLbpStackPostDepSetup_1,
    buildPostLbpStackPostDepSetup_2,
} from 'tasks/deployBuilds/postLbpStack/buildPostLbpStackPostDepSetup';
import { executeTestnetPostLbpStackPostDepSetup } from 'tasks/deployBuilds/postLbpStack/executeTestnetPostLbpStackPostDepSetup';
import { buildTapTokenReceiverModule } from '../deployBuilds/finalStack/options/tapToken/buildTapTokenReceiverModule';
import { buildTapTokenSenderModule } from '../deployBuilds/finalStack/options/tapToken/buildTapTokenSenderModule';
import { buildVesting } from '../deployBuilds/postLbpStack/vesting/buildVesting';
import { loadVM } from '../utils';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';

export const deployPostLbpStack__task = async (
    taskArgs: { tag?: string; load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = taskArgs.tag ?? 'default';
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        Number(hre.network.config.chainId),
    )!;

    const VM = await loadVM(hre, tag);
    const tapiocaMulticall = await VM.getMulticall();

    // Load previous deployment in the VM to execute after deployment setup
    if (taskArgs.load) {
        const data = hre.SDK.db.loadLocalDeployment(
            'default',
            String(hre.network.config.chainId),
        );
        if (!data) throw new Error('[-] No data found');
        VM.load(data.contracts);
    } else {
        const yieldBox = hre.SDK.db.findGlobalDeployment(
            TAPIOCA_PROJECTS_NAME.YieldBox,
            chainInfo!.chainId,
            'YieldBox',
            tag,
        );

        if (!yieldBox) {
            throw '[-] YieldBox not found';
        }

        // Build contracts
        VM.add(
            await buildAOTAP(hre, DEPLOYMENT_NAMES.AOTAP, [
                tapiocaMulticall.address,
            ]),
        )
            .add(await getVestingContributors(hre, tapiocaMulticall.address))
            .add(await getVestingEarlySupporters(hre, tapiocaMulticall.address))
            .add(await getVestingSupporters(hre, tapiocaMulticall.address))
            .add(await getAdb(hre, tapiocaMulticall.address))
            .add(
                await getTapTokenSenderModule(
                    hre,
                    tapiocaMulticall.address,
                    chainInfo.address,
                ),
            )
            .add(
                await getTapTokenReceiverModule(
                    hre,
                    tapiocaMulticall.address,
                    chainInfo.address,
                ),
            )
            .add(
                await getTapToken(
                    hre,
                    tapiocaMulticall.address,
                    chainInfo.address,
                ),
            );

        // Add and execute
        await VM.execute(3);
        await VM.save();
        await VM.verify();
    }

    // After deployment setup
    console.log('[+] After deployment setup');
    const isTestnet = chainInfo.tags.find((tag) => tag === 'testnet');
    // Create UniV3 Tap/WETH pool, TapOracle, USDCOracle
    if (!isTestnet) {
        await VM.executeMulticall(
            await buildPostLbpStackPostDepSetup_1(hre, tag),
        );
    } else {
        // Deploying testnet mock payment oracles
        // This'll also inject newly created USDC mock in DEPLOY_CONFIG
        await executeTestnetPostLbpStackPostDepSetup(hre, tag);
    }

    // Setup contracts
    await VM.executeMulticall(await buildPostLbpStackPostDepSetup_2(hre, tag));

    console.log('[+] Post LBP Stack deployed! 🎉');
};

async function getVestingContributors(
    hre: HardhatRuntimeEnvironment,
    owner: string,
) {
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_CONTRIBUTORS, [
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.CONTRIBUTORS_CLIFF, // 12 months cliff
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.CONTRIBUTORS_PERIOD, // 36 months vesting
        owner,
    ]);
}

async function getVestingEarlySupporters(
    hre: HardhatRuntimeEnvironment,
    owner: string,
) {
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_EARLY_SUPPORTERS, [
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING
            .EARLY_SUPPORTERS_CLIFF, // 0 months cliff
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING
            .EARLY_SUPPORTERS_PERIOD, // 24 months vesting
        owner,
    ]);
}

async function getVestingSupporters(
    hre: HardhatRuntimeEnvironment,
    owner: string,
) {
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_SUPPORTERS, [
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.SUPPORTERS_CLIFF, // 0 months cliff
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.SUPPORTERS_PERIOD, // 18 months vesting
        owner,
    ]);
}

async function getAdb(hre: HardhatRuntimeEnvironment, owner: string) {
    return await buildADB(
        hre,
        DEPLOYMENT_NAMES.AIRDROP_BROKER,
        [
            hre.ethers.constants.AddressZero, // aoTAP
            DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.PCNFT.ADDRESS, // PCNFT
            DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.ADB
                .PAYMENT_TOKEN_BENEFICIARY, // Payment token beneficiary
            owner, // Owner
        ],
        [
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.AOTAP,
            },
        ],
    );
}

async function getTapTokenSenderModule(
    hre: HardhatRuntimeEnvironment,
    owner: string,
    lzEndpointAddress: string,
) {
    return await buildTapTokenSenderModule(
        hre,
        DEPLOYMENT_NAMES.TAP_TOKEN_SENDER_MODULE,
        [
            '', // Name
            '', // Symbol
            lzEndpointAddress, // Endpoint address
            owner, // Owner
        ],
    );
}

async function getTapTokenReceiverModule(
    hre: HardhatRuntimeEnvironment,
    owner: string,
    lzEndpointAddress: string,
) {
    return await buildTapTokenReceiverModule(
        hre,
        DEPLOYMENT_NAMES.TAP_TOKEN_RECEIVER_MODULE,
        [
            '', // Name
            '', // Symbol
            lzEndpointAddress, // Endpoint address
            owner, // Owner
        ],
    );
}

async function getTapToken(
    hre: HardhatRuntimeEnvironment,
    owner: string,
    lzEndpointAddress: string,
) {
    return await buildTapToken(
        hre,
        DEPLOYMENT_NAMES.TAP_TOKEN,
        [
            lzEndpointAddress, // Endpoint address
            hre.ethers.constants.AddressZero, //contributors address
            hre.ethers.constants.AddressZero, // early supporters address
            hre.ethers.constants.AddressZero, // supporters address
            hre.ethers.constants.AddressZero, // aoTap address
            DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.TAP.DAO_ADDRESS, // DAO address
            hre.ethers.constants.AddressZero, // AirdropBroker address,
            ELZChainID.ARBITRUM, // Governance LZ ChainID
            owner, // Owner
            hre.ethers.constants.AddressZero, // TapTokenSenderModule
            hre.ethers.constants.AddressZero, // TapTokenReceiverModule
        ],
        [
            {
                argPosition: 1,
                deploymentName: DEPLOYMENT_NAMES.VESTING_CONTRIBUTORS,
            },
            {
                argPosition: 2,
                deploymentName: DEPLOYMENT_NAMES.VESTING_EARLY_SUPPORTERS,
            },
            {
                argPosition: 3,
                deploymentName: DEPLOYMENT_NAMES.VESTING_SUPPORTERS,
            },
            {
                argPosition: 3,
                deploymentName: DEPLOYMENT_NAMES.AOTAP,
            },
            {
                argPosition: 6,
                deploymentName: DEPLOYMENT_NAMES.AIRDROP_BROKER,
            },
            {
                argPosition: 9,
                deploymentName: DEPLOYMENT_NAMES.TAP_TOKEN_SENDER_MODULE,
            },
            {
                argPosition: 10,
                deploymentName: DEPLOYMENT_NAMES.TAP_TOKEN_RECEIVER_MODULE,
            },
        ],
    );
}
