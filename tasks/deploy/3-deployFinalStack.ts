import * as TAPIOCA_PERIPH_DEPLOY_CONFIG from '@tapioca-periph/config';
import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildFinalStackPostDepSetup_2 } from '../deployBuilds/finalStack/buildFinalStackPostDepSetup';
import { buildOTAP } from '../deployBuilds/finalStack/options/buildOTAP';
import { buildTOB } from '../deployBuilds/finalStack/options/buildTOB';
import { buildTolp } from '../deployBuilds/finalStack/options/buildTOLP';
import { buildTwTap } from '../deployBuilds/finalStack/options/deployTwTap';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';

/**
 * @notice Called after deployPostLbpStack_2__task & tapioca-periph final task & tapioca-bar final task
 *
 * Deploys: Arb
 * - TOLP
 * - OTAP
 * - TOB
 * - TWTAP
 *
 * Post deploy: Arb
 * - Register Arb SGL GLP in TOLP
 * - Register T SGL DAI in TOLP
 * - Set Cluster on tOLP, tOB, twTAP
 * - Set tOB as minter for TapOFT
 * - Set tOB Broker role for tOB on oTAP and init TapToken emissions
 * - Set TAP Oracle in tOB
 * - Set twTAP in TapOFT
 * - Set USDO as payment token in tOB if not set
 * - Set USDC as payment token in tOB if not set
 * - Set USDO as reward token in TwTap if not set
 */
export const deployFinalStack__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        tapiocaDeployTask,
        tapiocaPostDepSetup,
    );
};

async function tapiocaPostDepSetup(params: TTapiocaDeployerVmPass<object>) {
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    await VM.executeMulticall(
        await buildFinalStackPostDepSetup_2(hre, tag, isTestnet),
    );
}

async function tapiocaDeployTask(params: TTapiocaDeployerVmPass<object>) {
    const { hre, VM, tapiocaMulticallAddr, taskArgs, chainInfo } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    const { pearlmit, yieldBox } = await getContracts(hre, tag);

    VM.add(await getTolp(hre, owner, yieldBox.address, pearlmit.address))
        .add(await getOtap(hre, pearlmit.address, owner))
        .add(await getTob(hre, tag, owner, pearlmit.address))
        .add(await getTwTap(hre, tag, owner, pearlmit.address));
}

async function getContracts(hre: HardhatRuntimeEnvironment, tag: string) {
    const yieldBox = hre.SDK.db.findGlobalDeployment(
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        'YieldBox',
        tag,
    );

    if (!yieldBox) {
        throw '[-] YieldBox not found';
    }

    // Get pearlmit
    const pearlmit = hre.SDK.db.findGlobalDeployment(
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        TAPIOCA_PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.PEARLMIT,
        tag,
    );
    if (!pearlmit) {
        throw '[-] Pearlmit not found';
    }

    return {
        yieldBox,
        pearlmit,
    };
}

async function getTolp(
    hre: HardhatRuntimeEnvironment,
    owner: string,
    yieldBoxAddress: string,
    pearlmit: string,
) {
    return await buildTolp(
        hre,
        DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
        [
            yieldBoxAddress, // Yieldbox
            DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOLP.EPOCH_DURATION, // Epoch duration
            pearlmit,
            owner, // Owner
        ],
    );
}

async function getOtap(
    hre: HardhatRuntimeEnvironment,
    pearlmit: string,
    owner: string,
) {
    return await buildOTAP(hre, DEPLOYMENT_NAMES.OTAP, [pearlmit, owner]);
}

async function getTob(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    owner: string,
    pearlmit: string,
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
            '', // tOLP
            '', // oTAP
            tapToken.address, // TapOFT
            DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOB.PAYMENT_TOKEN_ADDRESS, // Payment token address
            DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOLP.EPOCH_DURATION, // Epoch duration
            pearlmit,
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
    pearlmit: string,
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
            pearlmit,
            owner, // Owner
        ],
        [],
    );
}
