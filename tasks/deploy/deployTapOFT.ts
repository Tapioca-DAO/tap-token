import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildTapOFT } from '../deployBuilds/01-buildTapOFT';
import { loadVM } from '../utils';

// hh deployTapOFT -network goerli
export const deployTapOFT__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const VM = await loadVM(hre, tag, false);
    const tapOft = await buildTapOFT(hre, signer.address);
    VM.add(tapOft);

    // Add and execute
    await VM.execute(3);
    VM.save();
    await VM.verify();
};
