import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
    EChainID,
    ELZChainID,
    TAPIOCA_PROJECTS_NAME,
} from '@tapioca-sdk/api/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTapToken } from 'tasks/deployBuilds/finalStack/options/tapToken/buildTapToken';
import { buildADB } from 'tasks/deployBuilds/postLbpStack/airdrop/buildADB';
import { buildAOTAP } from 'tasks/deployBuilds/postLbpStack/airdrop/buildAOTAP';
import { buildPostLbpStackPostDepSetup } from 'tasks/deployBuilds/postLbpStack/buildPostLbpStackPostDepSetup';
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
    const signer = (await hre.ethers.getSigners())[0];
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        Number(hre.network.config.chainId),
    )!;

    const VM = await loadVM(hre, tag);

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
        VM.add(await buildAOTAP(hre, DEPLOYMENT_NAMES.AOTAP, [signer.address]))
            .add(await getVestingContributors(hre, signer))
            .add(await getVestingEarlySupporters(hre, signer))
            .add(await getVestingSupporters(hre, signer))
            .add(await getAdb(hre, signer))
            .add(await getTapTokenSenderModule(hre, signer, chainInfo.address))
            .add(
                await getTapTokenReceiverModule(hre, signer, chainInfo.address),
            )
            .add(await getTapToken(hre, signer, chainInfo.address));

        // Add and execute
        await VM.execute(3);
        await VM.save();
        await VM.verify();
    }

    const vmList = VM.list();
    // After deployment setup

    console.log('[+] After deployment setup');
    const calls = await buildPostLbpStackPostDepSetup(hre, tag);

    // Execute
    // TODO Move this to SDK
    console.log('[+] Number of calls:', calls.length);
    const multicall = await VM.getMulticall();
    try {
        const tx = await (await multicall.multicall(calls)).wait(1);
        console.log(
            '[+] After deployment setup multicall Tx: ',
            tx.transactionHash,
        );
    } catch (e) {
        console.log('[-] After deployment setup multicall failed');
        console.log(
            '[+] Trying to execute calls one by one with owner account',
        );
        // If one fail, try them one by one with owner's account
        for (const call of calls) {
            // Static call simulation
            await signer.call({
                from: signer.address,
                data: call.callData,
                to: call.target,
            });

            await (
                await signer.sendTransaction({
                    data: call.callData,
                    to: call.target,
                })
            ).wait();
        }
    }

    console.log('[+] Stack deployed! 🎉');
};

async function getVestingContributors(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
) {
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_CONTRIBUTORS, [
        DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].VESTING.CONTRIBUTORS_CLIFF, // 12 months cliff
        DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].VESTING.CONTRIBUTORS_PERIOD, // 36 months vesting
        signer.address,
    ]);
}

async function getVestingEarlySupporters(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
) {
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_EARLY_SUPPORTERS, [
        DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].VESTING
            .EARLY_SUPPORTERS_CLIFF, // 0 months cliff
        DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].VESTING
            .EARLY_SUPPORTERS_PERIOD, // 24 months vesting
        signer.address,
    ]);
}

async function getVestingSupporters(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
) {
    return await buildVesting(hre, DEPLOYMENT_NAMES.VESTING_SUPPORTERS, [
        DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].VESTING.SUPPORTERS_CLIFF, // 0 months cliff
        DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].VESTING.SUPPORTERS_PERIOD, // 18 months vesting
        signer.address,
    ]);
}

async function getAdb(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
) {
    return await buildADB(
        hre,
        DEPLOYMENT_NAMES.AIRDROP_BROKER,
        [
            hre.ethers.constants.AddressZero, // aoTAP
            DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].PCNFT.ADDRESS, // PCNFT
            DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].ADB
                .PAYMENT_TOKEN_BENEFICIARY, // Payment token beneficiary
            signer.address, // Owner
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
    signer: SignerWithAddress,
    lzEndpointAddress: string,
) {
    return await buildTapTokenSenderModule(
        hre,
        DEPLOYMENT_NAMES.TAP_TOKEN_SENDER_MODULE,
        [
            '', // Name
            '', // Symbol
            lzEndpointAddress, // Endpoint address
            signer.address, // Owner
        ],
    );
}

async function getTapTokenReceiverModule(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
    lzEndpointAddress: string,
) {
    return await buildTapTokenReceiverModule(
        hre,
        DEPLOYMENT_NAMES.TAP_TOKEN_RECEIVER_MODULE,
        [
            '', // Name
            '', // Symbol
            lzEndpointAddress, // Endpoint address
            signer.address, // Owner
        ],
    );
}

async function getTapToken(
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
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
            DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].TAP.DAO_ADDRESS, // DAO address
            hre.ethers.constants.AddressZero, // AirdropBroker address,
            ELZChainID.ARBITRUM, // Governance LZ ChainID
            signer.address, // Owner
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
