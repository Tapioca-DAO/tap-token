import * as PERIPH_DEPLOY_CONFIG from '@tapioca-periph/config';
import { ELZChainID, TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import {
    IDependentOn,
    TTapiocaDeployTaskArgs,
} from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { BigNumberish } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadGlobalContract } from 'tapioca-sdk';
import {
    DeployerVM,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildADB } from 'tasks/deployBuilds/postLbpStack/airdrop/buildADB';
import { buildAOTAP } from 'tasks/deployBuilds/postLbpStack/airdrop/buildAOTAP';
import { buildExtExec } from 'tasks/deployBuilds/postLbpStack/tapToken/buildExtExec';
import { buildTapToken } from 'tasks/deployBuilds/postLbpStack/tapToken/buildTapToken';
import { loadTapTokenLocalContract } from 'tasks/utils';
import { buildTapTokenReceiverModule } from '../deployBuilds/postLbpStack/tapToken/buildTapTokenReceiverModule';
import { buildTapTokenSenderModule } from '../deployBuilds/postLbpStack/tapToken/buildTapTokenSenderModule';
import { buildVesting } from '../deployBuilds/postLbpStack/vesting/buildVesting';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';
import SUPPORTED_CHAINS from '@tapioca-sdk/SUPPORTED_CHAINS';
import { buildTapTokenHelper } from 'tasks/deployBuilds/postLbpStack/tapToken/buildTapTokenHelper';

/**
 * @notice Called after periph `lbp` task, before periph `postLbp` task
 * @notice Has a another task linked `deploySideChainPostLbpStack_1__task` that should be called after this task on sidechains
 *
 * Deploys: Arb
 * - AOTAP
 * - VestingContributors
 * - VestingEarlySupporters
 * - VestingSupporters
 * - ADB
 * - TapTokenSenderModule
 * - TapTokenReceiverModule
 * - TapToken
 * - TapTokenHelper
 *
 */
export const deployPostLbpStack_1__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        tapiocaDeployTask,
    );
};

async function tapiocaDeployTask(params: TTapiocaDeployerVmPass<object>) {
    // Settings
    const {
        hre,
        VM,
        tapiocaMulticallAddr,
        taskArgs,
        isTestnet,
        chainInfo,
        isHostChain,
        isSideChain,
    } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    // Build contracts
    if (isHostChain) {
        VM.add(await getAOTAP({ hre, owner, tag }))
            .add(await getVestingContributors({ hre, owner }))
            .add(await getVestingEarlySupporters({ hre, owner }))
            .add(await getVestingSupporters({ hre, owner }))
            .add(await getAdb({ hre, owner, tag }));

        await addTapTokenContractsVM({
            hre,
            tag,
            owner,
            VM,
            isTestnet,
            isHostChain,
            chainInfo,
            lzEndpointAddress: chainInfo.address,
        });
    } else {
        console.log('[-] Skipping  current chain is not host chain.');
    }
}

/**
 * @notice Add TapToken contracts to the VM
 */
export async function addTapTokenContractsVM(params: {
    hre: HardhatRuntimeEnvironment;
    tag: string;
    owner: string;
    VM: DeployerVM;
    lzEndpointAddress: string;
    isTestnet: boolean;
    isHostChain: boolean;
    chainInfo: (typeof SUPPORTED_CHAINS)[number];
}) {
    const {
        VM,
        isTestnet,
        isHostChain,
        lzEndpointAddress,
        hre,
        owner,
        chainInfo,
        tag,
    } = params;
    VM.add(await getExtExec({ hre, owner, tag }))
        .add(
            await getTapTokenSenderModule({
                hre,
                owner,
                lzEndpointAddress,
            }),
        )
        .add(
            await getTapTokenReceiverModule({
                hre,
                owner,
                lzEndpointAddress,
            }),
        )
        .add(
            await getTapToken({
                hre,
                tag,
                isTestnet: !!isTestnet,
                isHostChain,
                owner,
                lzEndpointAddress,
                chainInfo,
                governanceEid: isTestnet
                    ? ELZChainID.ARBITRUM_SEPOLIA
                    : ELZChainID.ARBITRUM, // Governance LZ ChainID
            }),
        )
        .add(await buildTapTokenHelper(hre));
}

async function getAOTAP(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
    tag: string;
}) {
    const { hre, owner, tag } = params;
    const { pearlmit } = loadContracts({ hre, tag });
    return await buildAOTAP(
        hre,
        DEPLOYMENT_NAMES.AOTAP,
        [pearlmit.address, owner],
        [],
    );
}

async function getVestingContributors(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
}) {
    const { hre, owner } = params;
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_CONTRIBUTORS, [
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.CONTRIBUTORS_CLIFF, // 12 months cliff
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.CONTRIBUTORS_PERIOD, // 36 months vesting
        owner,
    ]);
}

async function getVestingEarlySupporters(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
}) {
    const { hre, owner } = params;
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_EARLY_SUPPORTERS, [
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING
            .EARLY_SUPPORTERS_CLIFF, // 0 months cliff
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING
            .EARLY_SUPPORTERS_PERIOD, // 24 months vesting
        owner,
    ]);
}

async function getVestingSupporters(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
}) {
    const { hre, owner } = params;
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_SUPPORTERS, [
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.SUPPORTERS_CLIFF, // 0 months cliff
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.VESTING.SUPPORTERS_PERIOD, // 18 months vesting
        owner,
    ]);
}

async function getAdb(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
    tag: string;
}) {
    const { hre, owner, tag } = params;
    const { pearlmit } = loadContracts({ hre, tag });

    let paymentTokenBeneficiary: string =
        DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.ADB.PAYMENT_TOKEN_BENEFICIARY;

    if (hre.SDK.chainInfo.name === 'arbitrum_sepolia') {
        paymentTokenBeneficiary = owner;
    }

    return await buildADB(
        hre,
        DEPLOYMENT_NAMES.AIRDROP_BROKER,
        [
            hre.ethers.constants.AddressZero, // aoTAP
            DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.PCNFT.ADDRESS, // PCNFT
            paymentTokenBeneficiary, // Payment token beneficiary
            pearlmit.address, // Pearlmit
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

export async function getExtExec(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
    tag: string;
}) {
    const { hre, owner, tag } = params;
    return await buildExtExec(hre, DEPLOYMENT_NAMES.EXT_EXEC, [], []);
}

export async function getTapTokenSenderModule(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
    lzEndpointAddress: string;
}) {
    const { hre, owner, lzEndpointAddress } = params;
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

export async function getTapTokenReceiverModule(params: {
    hre: HardhatRuntimeEnvironment;
    owner: string;
    lzEndpointAddress: string;
}) {
    const { hre, owner, lzEndpointAddress } = params;
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

export async function getTapToken(params: {
    hre: HardhatRuntimeEnvironment;
    tag: string;
    isTestnet: boolean;
    isHostChain: boolean;
    owner: string;
    lzEndpointAddress: string;
    governanceEid: string;
    chainInfo: (typeof SUPPORTED_CHAINS)[number];
}) {
    const {
        hre,
        owner,
        tag,
        governanceEid,
        isTestnet,
        isHostChain,
        lzEndpointAddress,
        chainInfo,
    } = params;
    let lTap = { address: hre.ethers.constants.AddressZero };
    if (isHostChain) {
        lTap = loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.LTAP);
    }

    const { pearlmit, cluster } = loadContracts({ hre, tag });

    let dao = DEPLOY_CONFIG.POST_LBP[hre.SDK.eChainId]!.TAP.DAO_ADDRESS;
    dao = isTestnet ? owner : dao;

    const isGovernanceChain = chainInfo.lzChainId == governanceEid;
    return await buildTapToken(
        hre,
        DEPLOYMENT_NAMES.TAP_TOKEN,
        [
            {
                epochDuration:
                    DEPLOY_CONFIG.FINAL[hre.SDK.eChainId]!.TOLP.EPOCH_DURATION, // Epoch duration
                endpoint: lzEndpointAddress, // Endpoint address
                contributors: isTestnet ? owner : '0x', //contributors address, we use owner for testnet
                earlySupporters: hre.ethers.constants.AddressZero, // early supporters address
                supporters: hre.ethers.constants.AddressZero, // supporters address
                lTap: lTap.address, // lTap address
                dao, // DAO address
                airdrop: hre.ethers.constants.AddressZero, // AirdropBroker address,
                governanceEid: governanceEid,
                owner: owner, // Owner
                tapTokenSenderModule: hre.ethers.constants.AddressZero, // TapTokenSenderModule
                tapTokenReceiverModule: hre.ethers.constants.AddressZero, // TapTokenReceiverModule
                extExec: hre.ethers.constants.AddressZero, // ExtExec
                pearlmit: pearlmit.address,
                cluster: cluster.address,
            },
        ],
        getTapTokenDependencies({ isTestnet, isGovernanceChain }),
    );
}

/**
 * If governance chain, return all dependencies, otherwise return empty array
 */
function getTapTokenDependencies(params: {
    isGovernanceChain: boolean;
    isTestnet: boolean;
}): IDependentOn[] {
    const { isTestnet, isGovernanceChain } = params;
    let dependencies: IDependentOn[] = [
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
    ];

    if (isGovernanceChain) {
        // Inject multicall address as contributors if testnet
        if (!isTestnet) {
            dependencies = [
                ...dependencies,
                {
                    argPosition: 0,
                    deploymentName: DEPLOYMENT_NAMES.VESTING_CONTRIBUTORS,
                    keyName: 'contributors',
                },
            ];
        }
        // Inject vesting addresses
        dependencies = [
            ...dependencies,
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
        ];
    }

    return dependencies;
}

function loadContracts(params: {
    hre: HardhatRuntimeEnvironment;
    tag: string;
}) {
    const { hre, tag } = params;
    const pearlmit = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.PEARLMIT,
        tag,
    );

    const cluster = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.CLUSTER,
        tag,
    );

    return { pearlmit, cluster };
}
