import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';

export const configurePacketTypes__task = async (taskArgs: { src: string; dstLzChainId: string }, hre: HardhatRuntimeEnvironment) => {
    const packetTypes = [1, 2];

    const tapContract = await hre.ethers.getContractAt('TapOFT', taskArgs.src);

    for (var i = 0; i < packetTypes.length; i++) {
        await (await tapContract.setMinDstGas(taskArgs.dstLzChainId, packetTypes[i], 200000)).wait();
        await (await tapContract.setUseCustomAdapterParams(true)).wait();
    }
    console.log('\nDone');
};
