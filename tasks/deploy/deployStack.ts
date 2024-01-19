import { TAP_DISTRIBUTION } from '@tapioca-sdk/api/constants';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import { buildTapOFTv2 } from '../deployBuilds/01-buildTapOFTv2';
import { buildTOLP } from '../deployBuilds/02-buildTOLP';
import { buildOTAP } from '../deployBuilds/03-buildOTAP';
import { buildTOB } from '../deployBuilds/04-buildTOB';
import { buildTwTap } from '../deployBuilds/04-deployTwTap';
import { buildAfterDepSetup } from '../deployBuilds/05-buildAfterDepSetup';
import { buildTapOFTReceiverModule } from '../deployBuilds/TapOFTv2/buildTapOFTReceiverModule';
import { buildTapOFTSenderModule } from '../deployBuilds/TapOFTv2/buildTapOFTSenderModule';
import { buildVesting } from '../deployBuilds/buildVesting';
import { loadVM } from '../utils';
import { EChainID, TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';

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
        VM.load(data);
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
                await buildTapOFTSenderModule(hre, 'TapOFTSenderModule', [
                    lzEndpoint, // Endpoint address
                    signer.address, // Owner
                ]),
            )
            .add(
                await buildTapOFTReceiverModule(hre, 'TapOFTReceiverModule', [
                    lzEndpoint, // Endpoint address
                    signer.address, // Owner
                ]),
            )
            .add(
                await buildTapOFTv2(
                    hre,
                    'TapOFT',
                    [
                        lzEndpoint, // Static endpoint address, // TODO put it in config file
                        hre.ethers.constants.AddressZero, //contributors address
                        hre.ethers.constants.AddressZero, // early supporters address
                        hre.ethers.constants.AddressZero, // supporters address
                        chainInfoAddresses.lbpAddress,
                        chainInfoAddresses.daoAddress,
                        chainInfoAddresses.airdropAddress,
                        EChainID.ARBITRUM_SEPOLIA, // Governance LZ ChainID
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
                        { argPosition: 2, deploymentName: 'TapOFT' },
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
                    [{ argPosition: 0, deploymentName: 'TapOFT' }],
                ),
            );

        // Add and execute
        await VM.execute(3);
        VM.save();
        await VM.verify();
    }

    const vmList = VM.list();
    // After deployment setup

    const calls: Multicall3.CallStruct[] = [
        // Build testnet related calls
        ...(await buildAfterDepSetup(hre, vmList)),
    ];

    // Execute
    console.log('[+] After deployment setup calls number: ', calls.length);
    try {
        const multicall = await VM.getMulticall();
        const tx = await (await multicall.multicall(calls)).wait(1);
        console.log(
            '[+] After deployment setup multicall Tx: ',
            tx.transactionHash,
        );
    } catch (e) {
        // If one fail, try them one by one
        for (const call of calls) {
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
