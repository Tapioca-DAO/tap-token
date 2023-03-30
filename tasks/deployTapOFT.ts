import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/utils/MultiCall';
import { buildTapOFT } from './deploy/01-buildTapOFT';
import { buildTOLP } from './deploy/02-buildTOLP';
import { buildOTAP } from './deploy/03-buildOTAP';
import { buildTOB } from './deploy/04-buildTOB';
import { buildAfterDepSetup } from './deploy/05-buildAfterDepSetup';
import { buildYieldBoxMock } from './deploy/901-buildYieldBoxMock';
import { typechain } from 'tapioca-sdk';
import { loadVM } from './utils';

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
    await VM.execute(3, false);
    VM.save();
    await VM.verify();
};
