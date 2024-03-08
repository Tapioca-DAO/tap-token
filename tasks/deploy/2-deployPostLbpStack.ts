import { ELZChainID } from '@tapioca-sdk/api/config';
import { BigNumberish } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildADB } from 'tasks/deployBuilds/postLbpStack/airdrop/buildADB';
import { buildAOTAP } from 'tasks/deployBuilds/postLbpStack/airdrop/buildAOTAP';
import {
    buildPostLbpStackPostDepSetup_1,
    buildPostLbpStackPostDepSetup_2,
} from 'tasks/deployBuilds/postLbpStack/buildPostLbpStackPostDepSetup';
import { temp__buildCluster } from 'tasks/deployBuilds/postLbpStack/cluster/temp__buildCluster';
import { executeTestnetPostLbpStackPostDepSetup } from 'tasks/deployBuilds/postLbpStack/executeTestnetPostLbpStackPostDepSetup';
import { temp__buildPearlmit } from 'tasks/deployBuilds/postLbpStack/pearlmit/temp__buildPearlmit';
import { buildExtExec } from 'tasks/deployBuilds/postLbpStack/tapToken/buildExtExec';
import { buildTapToken } from 'tasks/deployBuilds/postLbpStack/tapToken/buildTapToken';
import { buildTapTokenReceiverModule } from '../deployBuilds/postLbpStack/tapToken/buildTapTokenReceiverModule';
import { buildTapTokenSenderModule } from '../deployBuilds/postLbpStack/tapToken/buildTapTokenSenderModule';
import { buildVesting } from '../deployBuilds/postLbpStack/vesting/buildVesting';
import { loadVM } from '../utils';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';

export const deployPostLbpStack__task = async (
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
    const isTestnet = chainInfo.tags.find((tag) => tag === 'testnet');

    if (taskArgs.load) {
        console.log(
            hre.SDK.db.loadLocalDeployment(tag, hre.SDK.eChainId)?.contracts,
        );
        VM.load(
            hre.SDK.db.loadLocalDeployment(tag, hre.SDK.eChainId)?.contracts ??
                [],
        );
    } else {
        // Build contracts
        VM.add(
            await temp__buildCluster(hre, DEPLOYMENT_NAMES.CLUSTER, [
                chainInfo.lzChainId,
                tapiocaMulticall.address,
            ]),
        )
            .add(
                await temp__buildPearlmit(hre, DEPLOYMENT_NAMES.PEARLMIT, [
                    'Pearlmit',
                    '1',
                ]),
            )
            .add(await getExtExec(hre, tapiocaMulticall.address))
            .add(await getAOTAP(hre, tapiocaMulticall.address))
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
                    tag,
                    !!isTestnet,
                    tapiocaMulticall.address,
                    chainInfo.address,
                    isTestnet
                        ? ELZChainID.ARBITRUM_SEPOLIA
                        : ELZChainID.ARBITRUM, // Governance LZ ChainID
                ),
            );

        // Add and execute
        await VM.execute();
        await VM.save();
    }
    if (taskArgs.verify) {
        await VM.verify();
    }

    // After deployment setup
    console.log('[+] After deployment setup');

    // Create UniV3 Tap/WETH pool, TapOracle, USDCOracle
    if (!isTestnet) {
        await VM.executeMulticall(
            await buildPostLbpStackPostDepSetup_1(hre, tag),
        );
    } else {
        // Deploying testnet mock payment oracles
        // This'll also inject newly created USDC mock in DEPLOY_CONFIG
        if (!taskArgs.load) {
            // Since it's deployments, if load is true, we don't need to deploy again
            await executeTestnetPostLbpStackPostDepSetup(
                hre,
                tag,
                taskArgs.verify,
            );
        }
    }
    // Setup contracts
    await VM.executeMulticall(await buildPostLbpStackPostDepSetup_2(hre, tag));

    console.log('[+] Post LBP Stack deployed! 🎉');
};

async function getExtExec(hre: HardhatRuntimeEnvironment, owner: string) {
    return await buildExtExec(
        hre,
        DEPLOYMENT_NAMES.EXT_EXEC,
        [
            hre.ethers.constants.AddressZero, // cluster
            owner,
        ],
        [
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.CLUSTER,
            },
        ],
    );
}

async function getAOTAP(hre: HardhatRuntimeEnvironment, owner: string) {
    return await buildAOTAP(
        hre,
        DEPLOYMENT_NAMES.AOTAP,
        [
            hre.ethers.constants.AddressZero, // Pearlmit
            owner,
        ],
        [
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.PEARLMIT,
            },
        ],
    );
}

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
            hre.ethers.constants.AddressZero, // Pearlmit
            owner, // Owner
        ],
        [
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.AOTAP,
            },
            {
                argPosition: 3,
                deploymentName: DEPLOYMENT_NAMES.PEARLMIT,
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
            hre.ethers.constants.AddressZero, // ExtExec
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
            hre.ethers.constants.AddressZero, // ExtExec
        ],
    );
}

async function getTapToken(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    isTestnet: boolean,
    owner: string,
    lzEndpointAddress: string,
    governanceEid: BigNumberish,
) {
    const lTap = hre.SDK.db.findLocalDeployment(
        hre.SDK.eChainId,
        DEPLOYMENT_NAMES.LTAP,
        tag,
    );
    if (!lTap) throw new Error('[-] lTap not found');

    return await buildTapToken(
        hre,
        DEPLOYMENT_NAMES.TAP_TOKEN,
        [
            {
                epochDuration:
                    DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOLP.EPOCH_DURATION, // Epoch duration
                endpoint: lzEndpointAddress, // Endpoint address
                contributors: hre.ethers.constants.AddressZero, //contributors address
                earlySupporters: hre.ethers.constants.AddressZero, // early supporters address
                supporters: hre.ethers.constants.AddressZero, // supporters address
                lTap: lTap.address, // lTap address
                dao: DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.TAP.DAO_ADDRESS, // DAO address
                airdrop: hre.ethers.constants.AddressZero, // AirdropBroker address,
                governanceEid: governanceEid,
                owner: owner, // Owner
                tapTokenSenderModule: hre.ethers.constants.AddressZero, // TapTokenSenderModule
                tapTokenReceiverModule: hre.ethers.constants.AddressZero, // TapTokenReceiverModule
                extExec: hre.ethers.constants.AddressZero, // ExtExec
                pearlmit: hre.ethers.constants.AddressZero, // Pearlmit
            },
        ],
        [
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.VESTING_CONTRIBUTORS,
                keyName: 'contributors',
            },
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.VESTING_EARLY_SUPPORTERS,
                keyName: 'earlySupporters',
            },
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.VESTING_SUPPORTERS,
                keyName: 'supporters',
            },
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.AIRDROP_BROKER,
                keyName: 'airdrop',
            },
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.TAP_TOKEN_SENDER_MODULE,
                keyName: 'tapTokenSenderModule',
            },
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.TAP_TOKEN_RECEIVER_MODULE,
                keyName: 'tapTokenReceiverModule',
            },
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.EXT_EXEC,
                keyName: 'extExec',
            },
            {
                argPosition: 0,
                deploymentName: DEPLOYMENT_NAMES.PEARLMIT,
                keyName: 'pearlmit',
            },
        ],
    );
}
