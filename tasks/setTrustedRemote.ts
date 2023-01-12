import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';
import { getDeployment } from './utils';

//npx hardhat setTrustedRemote --network goerli --chain 10106 --dst 0xa186155CB523CBEe7d8A12F332D39beC7937bdF0 --src 0xdb7677D723ED0B12E7A3945A4Ae234d4EFa4b91e
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10121 --dst 0xdb7677D723ED0B12E7A3945A4Ae234d4EFa4b91e --src 0xa186155CB523CBEe7d8A12F332D39beC7937bdF0

export const setTrustedRemote__task = async (taskArgs: { chain: string; dst: string; src: string }, hre: HardhatRuntimeEnvironment) => {
    console.log('\nRetrieving TapOFT');
    const tapContract = await getDeployment(hre, 'TapOFT');

    const path = hre.ethers.utils.solidityPack(['address', 'address'], [taskArgs.dst, taskArgs.src]);
    console.log(`Setting trusted remote with path ${path}`);
    await tapContract.setTrustedRemote(taskArgs.chain, path);

    console.log('Done');
};
