import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { EChainID, TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildFinalStackPostDepSetup } from '../deployBuilds/finalStack/buildFinalStackPostDepSetup';
import { buildOTAP } from '../deployBuilds/finalStack/options/buildOTAP';
import { buildTOB } from '../deployBuilds/finalStack/options/buildTOB';
import { buildTolp } from '../deployBuilds/finalStack/options/buildTOLP';
import { buildTwTap } from '../deployBuilds/finalStack/options/deployTwTap';
import { loadVM } from '../utils';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';
import { buildArbGlpYbStrategy } from 'tasks/deployBuilds/finalStack/buildArbGlpYbStrategy';

export const deployFinalStack__task = async (
    taskArgs: { tag?: string; load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = taskArgs.tag ?? 'default';
    const signer = (await hre.ethers.getSigners())[0];
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        Number(hre.network.config.chainId),
    )!;

    const VM = await loadVM(hre, tag);

    const yieldBox = hre.SDK.db.findGlobalDeployment(
        TAPIOCA_PROJECTS_NAME.YieldBox,
        chainInfo!.chainId,
        'YieldBox',
        tag,
    );

    if (!yieldBox) {
        throw '[-] YieldBox not found';
    }

    VM.add(await getTolp(hre, signer, yieldBox.address))
        .add(await buildOTAP(hre, DEPLOYMENT_NAMES.OTAP))
        .add(await getTob(hre, signer))
        .add(await getTwTap(hre, signer))
        .add(await getArbGlpYbStrategy(hre, yieldBox.address));

    // Add and execute
    await VM.execute(3);
    await VM.save();
    await VM.verify();

    // After deployment setup
    console.log('[+] After deployment setup');
    await VM.executeMulticall(await buildFinalStackPostDepSetup(hre, tag));

    console.log('[+] Stack deployed! 🎉');
};

async function getTolp(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
    yieldBoxAddress: string,
) {
    return await buildTolp(
        hre,
        DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
        [
            yieldBoxAddress, // Yieldbox
            DEPLOY_CONFIG.FINAL[EChainID.ARBITRUM].TOLP.EPOCH_DURATION, // Epoch duration
            signer.address, // Owner
        ],
    );
}

async function getTob(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
) {
    return await buildTOB(
        hre,
        DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER,
        [
            hre.ethers.constants.AddressZero, // tOLP
            hre.ethers.constants.AddressZero, // oTAP
            hre.ethers.constants.AddressZero, // TapOFT
            DEPLOY_CONFIG.FINAL[EChainID.ARBITRUM].TOB.PAYMENT_TOKEN_ADDRESS, // Payment token address
            DEPLOY_CONFIG.FINAL[EChainID.ARBITRUM].TOLP.EPOCH_DURATION, // Epoch duration
            signer.address, // Owner
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

async function getTwTap(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
) {
    return await buildTwTap(
        hre,
        DEPLOYMENT_NAMES.TWTAP,
        [
            hre.ethers.constants.AddressZero, // TapOFT
            signer.address, // Owner
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
    return await buildArbGlpYbStrategy(
        hre,
        DEPLOYMENT_NAMES.YB_SGL_GLP_STRATEGY,
        [
            yieldBoxAddress, // Yieldbox
            DEPLOYMENT_NAMES.ARBITRUM_SGL_GLP, // Underlying token // TODO move name to config
        ],
    );
}
