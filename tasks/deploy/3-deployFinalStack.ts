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
    const isTestnet = chainInfo.tags.find((tag) => tag === 'testnet');

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
            .add(await getTob(hre, tag, tapiocaMulticall.address))
            .add(await getTwTap(hre, tag, tapiocaMulticall.address));

        // Add and execute
        await VM.execute();
        await VM.save();
        if (taskArgs.verify) {
            await VM.verify();
        }
    }

    // After deployment setup
    console.log('[+] After deployment setup');

    // Execute testnet setup. Deploy mocks and other testnet specific contracts that comes from tapioca-bar
    if (isTestnet) {
        await executeTestnetFinalStackPostDepSetup(
            hre,
            tag,
            yieldBox,
            taskArgs.verify,
        );
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

async function getTob(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    owner: string,
) {
    const tapToken = hre.SDK.db.findLocalDeployment(
        hre.SDK.eChainId,
        DEPLOYMENT_NAMES.TAP_TOKEN,
        tag,
    );
    if (!tapToken) throw new Error('[-] TapToken not found');

    return await buildTOB(
        hre,
        DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER,
        [
            hre.ethers.constants.AddressZero, // tOLP
            hre.ethers.constants.AddressZero, // oTAP
            tapToken.address, // TapOFT
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
        ],
    );
}

async function getTwTap(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    owner: string,
) {
    const tapToken = hre.SDK.db.findLocalDeployment(
        hre.SDK.eChainId,
        DEPLOYMENT_NAMES.TAP_TOKEN,
        tag,
    );
    if (!tapToken) throw new Error('[-] TapToken not found');

    return await buildTwTap(
        hre,
        DEPLOYMENT_NAMES.TWTAP,
        [
            tapToken.address, // TapOFT
            owner, // Owner
        ],
        [],
    );
}
