import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTapOFT } from '../deployBuilds/01-buildTapOFT';
import { loadVM } from '../utils';
import { TAP_DISTRIBUTION } from '../../gitsub_tapioca-sdk/src/api/constants';
import { EChainID } from '../../gitsub_tapioca-sdk/src/api/config';

// hh deployTapOFT -network goerli
export const deployTapOFT__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const VM = await loadVM(hre, tag, false);

    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        await hre.getChainId(),
    )!;

    const lzEndpoint = chainInfo.address;
    const chainInfoAddresses =
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]!;
    const tapOft = await buildTapOFT(hre, 'TapOFT', [
        lzEndpoint,
        chainInfoAddresses.teamAddress, //contributor address
        chainInfoAddresses.earlySupportersAddress,
        chainInfoAddresses.supportersAddress,
        chainInfoAddresses.lbpAddress,
        chainInfoAddresses.daoAddress,
        chainInfoAddresses.airdropAddress,
        EChainID.ARBITRUM_GOERLI, //governance chain
        signer.address,
    ]);
    VM.add(tapOft);

    // Add and execute
    await VM.execute(3);
    VM.save();
    await VM.verify();
};
