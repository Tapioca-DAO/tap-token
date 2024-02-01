import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildEmptyYbStrategy } from 'tasks/deployBuilds/finalStack/buildEmptyYbStrategy';
import { executeTestnetFinalStackPostDepSetup } from 'tasks/deployBuilds/finalStack/executeTestnetFinalStackPostDepSetup';
import {
    buildFinalStackPostDepSetup_1,
    buildFinalStackPostDepSetup_2,
} from '../deployBuilds/finalStack/buildFinalStackPostDepSetup';
import { buildOTAP } from '../deployBuilds/finalStack/options/buildOTAP';
import { buildTOB } from '../deployBuilds/finalStack/options/buildTOB';
import { buildTolp } from '../deployBuilds/finalStack/options/buildTOLP';
import { buildTwTap } from '../deployBuilds/finalStack/options/deployTwTap';
import { loadVM } from '../utils';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';

export const deployFinalStack__task = async (
    taskArgs: { tag?: string; load?: boolean; verify: boolean },
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

    const yieldBox = hre.SDK.db.findGlobalDeployment(
        TAPIOCA_PROJECTS_NAME.YieldBox,
        chainInfo!.chainId,
        'YieldBox',
        tag,
    );

    if (!yieldBox) {
        throw '[-] YieldBox not found';
    }

    if (taskArgs.load) {
        VM.load(
            hre.SDK.db.loadLocalDeployment(tag, hre.SDK.eChainId)?.contracts ??
                [],
        );
    } else {
        VM.add(await getTolp(hre, tapiocaMulticall.address, yieldBox.address))
            .add(await buildOTAP(hre, DEPLOYMENT_NAMES.OTAP))
            .add(await getTob(hre, tapiocaMulticall.address))
            .add(await getTwTap(hre, tapiocaMulticall.address))
            .add(await getArbGlpYbStrategy(hre, yieldBox.address))
            .add(await getMainnetDaiYbStrategy(hre, yieldBox.address));

        // Add and execute
        await VM.execute();
        await VM.save();
        if (taskArgs.verify) {
            await VM.verify();
        }
    }

    // After deployment setup
    console.log('[+] After deployment setup');
    const isTestnet = chainInfo.tags.find((tag) => tag === 'testnet');

    // Execute testnet setup. Deploy mocks and other testnet specific contracts that comes from tapioca-bar
    if (isTestnet) {
        await executeTestnetFinalStackPostDepSetup(hre, tag);
    }

    await VM.executeMulticall(
        await buildFinalStackPostDepSetup_1(hre, tag, tapiocaMulticall.address),
    );
    await VM.executeMulticall(await buildFinalStackPostDepSetup_2(hre, tag));

    console.log('[+] Stack deployed! 🎉');
};

async function getTolp(
    hre: HardhatRuntimeEnvironment,
    owner: string,
    yieldBoxAddress: string,
) {
    return await buildTolp(
        hre,
        DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
        [
            yieldBoxAddress, // Yieldbox
            DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOLP.EPOCH_DURATION, // Epoch duration
            owner, // Owner
        ],
    );
}

async function getTob(hre: HardhatRuntimeEnvironment, owner: string) {
    return await buildTOB(
        hre,
        DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER,
        [
            hre.ethers.constants.AddressZero, // tOLP
            hre.ethers.constants.AddressZero, // oTAP
            hre.ethers.constants.AddressZero, // TapOFT
            DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOB.PAYMENT_TOKEN_ADDRESS, // Payment token address
            DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOLP.EPOCH_DURATION, // Epoch duration
            owner, // Owner
        ],
        [
            {
                argPosition: 0,
                deploymentName:
                    DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
            },
            { argPosition: 1, deploymentName: DEPLOYMENT_NAMES.OTAP },
            {
                argPosition: 2,
                deploymentName: DEPLOYMENT_NAMES.TAP_TOKEN,
            },
        ],
    );
}

async function getTwTap(hre: HardhatRuntimeEnvironment, owner: string) {
    return await buildTwTap(
        hre,
        DEPLOYMENT_NAMES.TWTAP,
        [
            hre.ethers.constants.AddressZero, // TapOFT
            owner, // Owner
        ],
        [
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.TAP_TOKEN,
            },
        ],
    );
}

async function getArbGlpYbStrategy(
    hre: HardhatRuntimeEnvironment,
    yieldBoxAddress: string,
) {
    return await buildEmptyYbStrategy(
        hre,
        DEPLOYMENT_NAMES.YB_SGL_ARB_GLP_STRATEGY,
        [
            yieldBoxAddress, // Yieldbox
            DEPLOYMENT_NAMES.ARBITRUM_SGL_GLP, // Underlying token // TODO move name to config
        ],
    );
}

async function getMainnetDaiYbStrategy(
    hre: HardhatRuntimeEnvironment,
    yieldBoxAddress: string,
) {
    return await buildEmptyYbStrategy(
        hre,
        DEPLOYMENT_NAMES.YB_SGL_MAINNET_DAI_STRATEGY,
        [
            yieldBoxAddress, // Yieldbox
            DEPLOYMENT_NAMES.MAINNET_SGL_DAI, // Underlying token // TODO move name to config
        ],
    );
}
