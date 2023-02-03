import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';
import { getDeployment } from './utils';

//to mumbai
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0x78Ab2649fd6682e5c3CCFABb87ed6FcED0843cE4 --src 0xC27F48670cDae9Eee92156209642d47Ea1B85a35
//  npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0x78Ab2649fd6682e5c3CCFABb87ed6FcED0843cE4 --src 0xBEb739E11742D7015B807012894bDA8b0fe6b141

//to fuji
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0xBEb739E11742D7015B807012894bDA8b0fe6b141 --src 0xC27F48670cDae9Eee92156209642d47Ea1B85a35
//  npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0xBEb739E11742D7015B807012894bDA8b0fe6b141 --src 0x78Ab2649fd6682e5c3CCFABb87ed6FcED0843cE4

//to arb_goerli
//  npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0xC27F48670cDae9Eee92156209642d47Ea1B85a35 --src 0xBEb739E11742D7015B807012894bDA8b0fe6b141
//  npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0xC27F48670cDae9Eee92156209642d47Ea1B85a35 --src 0x78Ab2649fd6682e5c3CCFABb87ed6FcED0843cE4

export const setTrustedRemote__task = async (taskArgs: { chain: string; dst: string; src: string }, hre: HardhatRuntimeEnvironment) => {
    console.log('\nRetrieving TapOFT');
    const tapContract = await getDeployment(hre, 'TapOFT');

    const path = hre.ethers.utils.solidityPack(['address', 'address'], [taskArgs.dst, taskArgs.src]);
    console.log(`Setting trusted remote with path ${path}`);
    await tapContract.setTrustedRemote(taskArgs.chain, path);

    console.log('Done');
};
