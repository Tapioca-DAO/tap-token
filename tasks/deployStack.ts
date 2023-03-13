import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/utils/MultiCall';
import { Multicall3__factory } from '../typechain';
import { buildTapOFT } from './deploy/01-buildTapOFT';
import { buildTOLP } from './deploy/02-buildTOLP';
import { buildOTAP } from './deploy/03-buildOTAP';
import { buildTOB } from './deploy/04-buildTOB';
import { buildYieldBoxMock } from './deploy/901-buildYieldBoxMock';

import { DeployerVM } from './deployerVM';

// TODO - Refactor steps to external function to lighten up the task
export const deployStack__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    // Settings
    const signer = (await hre.ethers.getSigners())[0];
    const VM = new DeployerVM(hre, {
        multicall: Multicall3__factory.connect(
            hre.SDK.config.MULTICALL_ADDRESS,
            signer,
        ),
    });

    // TODO - To remove
    // Build YieldBox on the go:)
    const yb = await buildYieldBoxMock(hre);
    VM.add(yb[0]).add(yb[1]);

    // Build contracts
    VM.add(await buildTapOFT(hre))
        .add(await buildTOLP(hre, signer.address))
        .add(await buildOTAP(hre))
        .add(await buildTOB(hre, signer.address, signer.address));

    // Add and execute
    await VM.execute(3);
    VM.save();
    await VM.verify();

    // After deployment setup
    const multiCall = await hre.ethers.getContractAt(
        'Multicall3',
        hre.SDK.config.MULTICALL_ADDRESS,
    );
    const calls: Multicall3.Call3Struct[] = [];
};
