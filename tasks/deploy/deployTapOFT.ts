import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTapOFT } from '../deployBuilds/01-buildTapOFT';
import { loadVM } from '../utils';
import { TAP_DISTRIBUTION } from '../../gitsub_tapioca-sdk/src/api/constants';
import { EChainID } from 'tapioca-sdk/dist/api/config';

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
    );

    const tapOft = await buildTapOFT(hre, [
        chainInfo?.address,
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.teamAddress, //contributor address
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]
            ?.earlySupportersAddress,
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.supportersAddress,
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.lbpAddress,
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.daoAddress,
        TAP_DISTRIBUTION[chainInfo?.chainId as EChainID]?.airdropAddress,
        EChainID.ARBITRUM_GOERLI, //governance chain
        signer.address,
    ]);
    VM.add(tapOft);

    // Add and execute
    await VM.execute(3);
    VM.save();
    await VM.verify();
};
