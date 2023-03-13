import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { constants } from '../scripts/deployment.utils';
import { Multicall3__factory, TapOFT__factory } from '../typechain';

import { DeployerVM } from './deployerVM';

export const deployStack__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    const signer = hre.ethers.provider.getSigner(0);
    const VM = new DeployerVM(hre, {
        multicall: Multicall3__factory.connect(
            hre.SDK.config.MULTICALL_ADDRESS,
            signer,
        ),
    });

    // Step 1 - Build TapOFT
    const chainId = await hre.getChainId();
    const lzEndpoint = constants[chainId as '5'].address as string;
    const contributorAddress = constants.teamAddress;
    const investorAddress = constants.advisorAddress;
    const lbpAddress = constants.daoAddress;
    const airdropAddress = constants.seedAddress;
    const daoAddress = constants.daoAddress;
    const governanceChainId = constants.governanceChainId.toString();
    const args: Parameters<TapOFT__factory['deploy']> = [
        lzEndpoint,
        contributorAddress,
        investorAddress,
        lbpAddress,
        daoAddress,
        airdropAddress,
        governanceChainId,
    ];

    await VM.add({
        contract: await hre.ethers.getContractFactory('TapOFT'),
        deploymentName: 'TapOFT',
        args,
    }).execute();

    const list = VM.list();
    const tap = await hre.ethers.getContractAt('TapOFT', list[0].address);
    console.log(await tap.WEEK());
};
