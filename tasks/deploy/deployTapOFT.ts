import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTapOFT } from '../deployBuilds/01-buildTapOFT';
import { loadVM } from '../utils';
import { constants } from '../../scripts/deployment.utils';

// hh deployTapOFT -network goerli
export const deployTapOFT__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const VM = await loadVM(hre, tag, false);

    const chainId = await hre.getChainId();
    const lzEndpoint = constants[chainId as '5'].address as string;
    const contributorAddress = constants.teamAddress;
    const earlySupportersAddress = constants.earlySupportersAddress;
    const supportersAddress = constants.supportersAddress;
    const lbpAddress = constants.daoAddress;
    const airdropAddress = constants.seedAddress;
    const daoAddress = constants.daoAddress;
    const governanceChainId = constants.governanceChainId.toString();

    const tapOft = await buildTapOFT(hre, [
        lzEndpoint,
        contributorAddress,
        earlySupportersAddress,
        supportersAddress,
        lbpAddress,
        daoAddress,
        airdropAddress,
        governanceChainId,
        signer.address,
    ]);
    VM.add(tapOft);

    // Add and execute
    await VM.execute(3);
    VM.save();
    await VM.verify();
};
