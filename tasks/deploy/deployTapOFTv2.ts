import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTapOFTv2 } from '../deployBuilds/01-buildTapOFTv2';
import { loadVM } from '../utils';
import { TAP_DISTRIBUTION } from '@tapioca-sdk/api/constants';
import { EChainID, ELZChainID } from '@tapioca-sdk/api/config';
import inquirer from 'inquirer';
import { buildTapOFTSenderModule } from '../deployBuilds/TapOFTv2/buildTapOFTSenderModule';
import { buildTapOFTReceiverModule } from '../deployBuilds/TapOFTv2/buildTapOFTReceiverModule';
import { buildTapOFTHelper } from '../deployBuilds/TapOFTv2/buildTapOFTHelper';

// hh deployTapOFT -network goerli
export const deployTapOFTv2__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const VM = await loadVM(hre, tag);

    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        Number(hre.network.config.chainId),
    )!;
    const chainInfoAddresses =
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]!;
    const isTestnet = chainInfo.tags[0] == 'testnet';
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
    }

    const lzEndpoint = chainInfo.address;

    VM.add(
        await buildTapOFTSenderModule(hre, 'TapOFTSenderModule', [
            '0x464570adA09869d8741132183721B4f0769a0287', // Endpoint address
            signer.address, // Owner
        ]),
    )
        .add(
            await buildTapOFTReceiverModule(hre, 'TapOFTReceiverModule', [
                '0x464570adA09869d8741132183721B4f0769a0287', // Endpoint address
                signer.address, // Owner
            ]),
        )
        .add(
            await buildTapOFTv2(
                hre,
                'TapOFTv2',
                [
                    '0x464570adA09869d8741132183721B4f0769a0287',
                    signer.address, //contributor address, // TODO change to a real contributor address
                    chainInfoAddresses.earlySupportersAddress,
                    chainInfoAddresses.supportersAddress,
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
        .add(await buildTapOFTHelper(hre, 'TapOFTHelper', []));

    // Add and execute
    await VM.execute(3);
    VM.save();
    await VM.verify();
};
