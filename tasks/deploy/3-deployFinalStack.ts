import {
    EChainID,
    ELZChainID,
    TAPIOCA_PROJECTS_NAME,
} from '@tapioca-sdk/api/config';
import { TAP_DISTRIBUTION } from '@tapioca-sdk/api/constants';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTOLP } from '../deployBuilds/finalStack/options/buildTOLP';
import { buildOTAP } from '../deployBuilds/finalStack/options/buildOTAP';
import { buildTOB } from '../deployBuilds/finalStack/options/buildTOB';
import { buildTwTap } from '../deployBuilds/finalStack/options/deployTwTap';
import { buildStackPostDepSetup } from '../deployBuilds/finalStack/buildFinalStackPostDepSetup';
import { buildTapTokenReceiverModule } from '../deployBuilds/finalStack/options/tapToken/buildTapTokenReceiverModule';
import { buildTapTokenSenderModule } from '../deployBuilds/finalStack/options/tapToken/buildTapTokenSenderModule';
import { buildVesting } from '../deployBuilds/postLbpStack/vesting/buildVesting';
import { loadVM } from '../utils';
import { buildTapToken } from 'tasks/deployBuilds/finalStack/options/tapToken/buildTapToken';

// hh deployStack --type build --network goerli
export const deployFinalStack__task = async (
    taskArgs: { tag?: string; load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = taskArgs.tag ?? 'default';
    const signer = (await hre.ethers.getSigners())[0];
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        Number(hre.network.config.chainId),
    )!;
    const isTestnet = chainInfo.tags[0] == 'testnet';

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

    VM.add(
        await buildTOLP(hre, 'TapiocaOptionLiquidityProvision', [
            signer.address,
            tapiocaOptionBrokerEpochDuration,
            yieldBox?.address,
        ]),
    )
        .add(await buildOTAP(hre, 'OTAP'))
        .add(
            await buildTOB(
                hre,
                'TapiocaOptionBroker',
                [
                    hre.ethers.constants.AddressZero, // tOLP
                    hre.ethers.constants.AddressZero, // oTAP
                    hre.ethers.constants.AddressZero, // TapOFT
                    signer.address,
                    tapiocaOptionBrokerEpochDuration,
                    signer.address,
                ],
                [
                    {
                        argPosition: 0,
                        deploymentName: 'TapiocaOptionLiquidityProvision',
                    },
                    { argPosition: 1, deploymentName: 'OTAP' },
                    { argPosition: 2, deploymentName: 'TapToken' },
                ],
            ),
        )
        .add(
            await buildTwTap(
                hre,
                [
                    hre.ethers.constants.AddressZero, // TapOFT
                    signer.address,
                ],
                [{ argPosition: 0, deploymentName: 'TapToken' }],
            ),
        );

    // Add and execute
    await VM.execute(3);
    await VM.save();
    await VM.verify();

    const vmList = VM.list();
    // After deployment setup

    console.log('[+] After deployment setup');
    const calls = await buildStackPostDepSetup(hre, vmList);

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
