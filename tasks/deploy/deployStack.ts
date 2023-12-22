import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import {
    EChainID,
    TAPIOCA_PROJECTS_NAME,
} from '../../gitsub_tapioca-sdk/src/api/config';
import { TAP_DISTRIBUTION } from '../../gitsub_tapioca-sdk/src/api/constants';
import { buildTapOFT } from '../deployBuilds/01-buildTapOFT';
import { buildTOLP } from '../deployBuilds/02-buildTOLP';
import { buildOTAP } from '../deployBuilds/03-buildOTAP';
import { buildTOB } from '../deployBuilds/04-buildTOB';
import { buildTwTap } from '../deployBuilds/04-deployTwTap';
import { buildAfterDepSetup } from '../deployBuilds/05-buildAfterDepSetup';
import { loadVM } from '../utils';
import { buildVesting } from '../deployBuilds/buildVesting';
import inquirer from 'inquirer';

// hh deployStack --type build --network goerli
export const deployStack__task = async (
    taskArgs: { load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        await hre.getChainId(),
    )!;
    const isTestnet = chainInfo.tags[0] == 'testnet';

    const VM = await loadVM(hre, tag);

    if (taskArgs.load) {
        const data = hre.SDK.db.loadLocalDeployment(
            'default',
            String(hre.network.config.chainId),
        );
        VM.load(data);
    } else {
        const yieldBox = hre.SDK.db
            .loadGlobalDeployment(
                tag,
                TAPIOCA_PROJECTS_NAME.TapiocaBar,
                chainInfo!.chainId,
            )
            .find((e) => e.name === 'YieldBox');

        if (!yieldBox) {
            throw '[-] YieldBox not found';
        }

        // Build contracts
        const lzEndpoint = chainInfo.address;
        const chainInfoAddresses =
            TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]!;

        let vestingContributorsCliff = 31104000, // 12 months cliff
            vestingContributorsPeriod = 93312000; // 36 months vesting
        let vestingEarlySupportersCliff = 0,
            vestingEarlySupportersPeriod = 62208000; // 24 months vesting
        let vestingSupportersCliff = 0,
            vestingSupportersPeriod = 46656000; // 18 months vesting
        let tapiocaOptionBrokerEpochDuration = 604800; //7 days
        if (!isTestnet) {
            const addresses = `( teamAddress: ${chainInfoAddresses.teamAddress}; earlySupportersAddress: ${chainInfoAddresses.earlySupportersAddress}; supportersAddress: ${chainInfoAddresses.supportersAddress}; lbpAddress: ${chainInfoAddresses.lbpAddress}; daoAddress: ${chainInfoAddresses.daoAddress}; airdropAddress: ${chainInfoAddresses.airdropAddress})`;

            const { isOk } = await inquirer.prompt({
                type: 'confirm',
                message: `Are you sure TAP distribution is updated ? ${addresses}`,
                name: 'isOk',
            });

            if (!isOk) {
                throw new Error('[-] Aborted');
            }

            tapiocaOptionBrokerEpochDuration = (
                await inquirer.prompt({
                    type: 'input',
                    name: 'tapiocaOptionBrokerEpochDuration',
                    message: 'Tapioca Option Broker epoch duration',
                    default: tapiocaOptionBrokerEpochDuration,
                })
            ).tapiocaOptionBrokerEpochDuration;

            vestingContributorsCliff = (
                await inquirer.prompt({
                    type: 'input',
                    name: 'vestingContributorsCliff',
                    message: 'Vesting contributors cliff',
                    default: vestingContributorsCliff,
                })
            ).vestingContributorsCliff;

            vestingContributorsPeriod = (
                await inquirer.prompt({
                    type: 'input',
                    name: 'vestingContributorsPeriod',
                    message: 'Vesting contributors period',
                    default: vestingContributorsPeriod,
                })
            ).vestingContributorsPeriod;

            vestingEarlySupportersCliff = (
                await inquirer.prompt({
                    type: 'input',
                    name: 'vestingEarlySupportersCliff',
                    message: 'Vesting early supporters cliff',
                    default: vestingEarlySupportersCliff,
                })
            ).vestingEarlySupportersCliff;

            vestingEarlySupportersPeriod = (
                await inquirer.prompt({
                    type: 'input',
                    name: 'vestingEarlySupportersPeriod',
                    message: 'Vesting early supporters period',
                    default: vestingEarlySupportersPeriod,
                })
            ).vestingEarlySupportersPeriod;

            vestingSupportersCliff = (
                await inquirer.prompt({
                    type: 'input',
                    name: 'vestingSupportersCliff',
                    message: 'Vesting supporters cliff',
                    default: vestingSupportersCliff,
                })
            ).vestingSupportersCliff;

            vestingSupportersPeriod = (
                await inquirer.prompt({
                    type: 'input',
                    name: 'vestingSupportersPeriod',
                    message: 'Vesting supporters period',
                    default: vestingSupportersPeriod,
                })
            ).vestingSupportersPeriod;
        }

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
                await buildTapOFT(
                    hre,
                    'TapOFT',
                    [
                        lzEndpoint,
                        hre.ethers.constants.AddressZero, //contributors address
                        hre.ethers.constants.AddressZero, // early supporters address
                        hre.ethers.constants.AddressZero, // supporters address
                        chainInfoAddresses.lbpAddress,
                        chainInfoAddresses.daoAddress,
                        chainInfoAddresses.airdropAddress,
                        EChainID.ARBITRUM_GOERLI, //governance chain
                        signer.address,
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
