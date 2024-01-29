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
export const deployStack__task = async (
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
        const lzEndpoint = '0x464570adA09869d8741132183721B4f0769a0287'; // TODO replace by: chainInfo.address
        const chainInfoAddresses =
            TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]!;

        const vestingContributorsCliff = 31104000, // 12 months cliff
            vestingContributorsPeriod = 93312000; // 36 months vesting
        const vestingEarlySupportersCliff = 0,
            vestingEarlySupportersPeriod = 62208000; // 24 months vesting
        const vestingSupportersCliff = 0,
            vestingSupportersPeriod = 46656000; // 18 months vesting
        const tapiocaOptionBrokerEpochDuration = 604800; //7 days

        const addresses = `( teamAddress: ${chainInfoAddresses.teamAddress}; earlySupportersAddress: ${chainInfoAddresses.earlySupportersAddress}; supportersAddress: ${chainInfoAddresses.supportersAddress}; lbpAddress: ${chainInfoAddresses.lbpAddress}; daoAddress: ${chainInfoAddresses.daoAddress}; airdropAddress: ${chainInfoAddresses.airdropAddress})`;
        console.log(addresses);

        VM.add(
            await buildVesting(hre, 'VestingContributors', [
                vestingContributorsCliff, // 12 months cliff
                vestingContributorsPeriod, // 36 months vesting
                signer.address,
            ]),
        )
            .add(
                await buildVesting(hre, 'VestingEarlySupporters', [
                    vestingEarlySupportersCliff, // 0 months cliff
                    vestingEarlySupportersPeriod, // 24 months vesting
                    signer.address,
                ]),
            )
            .add(
                await buildVesting(hre, 'VestingSupporters', [
                    vestingSupportersCliff, // 0 months cliff
                    vestingSupportersPeriod, // 18 months vesting
                    signer.address,
                ]),
            )
            .add(
                await buildTapTokenSenderModule(hre, 'TapOFTSenderModule', [
                    '', // Name
                    '', // Symbol
                    lzEndpoint, // Endpoint address
                    signer.address, // Owner
                ]),
            )
            .add(
                await buildTapTokenReceiverModule(hre, 'TapOFTReceiverModule', [
                    '', // Name
                    '', // Symbol
                    lzEndpoint, // Endpoint address
                    signer.address, // Owner
                ]),
            )
            .add(
                await buildTapToken(
                    hre,
                    'TapToken',
                    [
                        lzEndpoint, // Static endpoint address, // TODO put it in config file
                        hre.ethers.constants.AddressZero, //contributors address
                        hre.ethers.constants.AddressZero, // early supporters address
                        hre.ethers.constants.AddressZero, // supporters address
                        chainInfoAddresses.lbpAddress,
                        chainInfoAddresses.daoAddress,
                        chainInfoAddresses.airdropAddress,
                        ELZChainID.ARBITRUM_SEPOLIA, // Governance LZ ChainID
                        signer.address,
                        hre.ethers.constants.AddressZero, // TapOFTSenderModule
                        hre.ethers.constants.AddressZero, // TapOFTReceiverModule
                    ],
                    [
                        {
                            argPosition: 1,
                            deploymentName: 'VestingContributors',
                        },
                        {
                            argPosition: 2,
                            deploymentName: 'VestingEarlySupporters',
                        },
                        {
                            argPosition: 3,
                            deploymentName: 'VestingSupporters',
                        },
                        {
                            argPosition: 9,
                            deploymentName: 'TapOFTSenderModule',
                        },
                        {
                            argPosition: 10,
                            deploymentName: 'TapOFTReceiverModule',
                        },
                    ],
                ),
            )
            .add(
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
        // await VM.verify();
    }

    const vmList = VM.list();
    // After deployment setup

    console.log('[+] After deployment setup');
    const calls = await buildStackPostDepSetup(hre, vmList);

    // Execute
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
