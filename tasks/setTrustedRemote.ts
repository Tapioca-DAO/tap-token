import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';
import { getDeployment } from './utils';

// 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D
// 10112

//to mumbai
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0xd621150f4BE5b6E537f61dB2A59499F648F1B6e2 --src 0x31dA039c8Cf6eDC95fAFECb7B3E70a308128b7E0
//  npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0xd621150f4BE5b6E537f61dB2A59499F648F1B6e2 --src 0xc6B03Ba05Fb5E693D8b3533aa676FB4AFDd7DDc7
//  npx hardhat setTrustedRemote --network fantom_testnet --chain 10109 --dst 0xd621150f4BE5b6E537f61dB2A59499F648F1B6e2 --src 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D

//to fuji
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0xc6B03Ba05Fb5E693D8b3533aa676FB4AFDd7DDc7 --src 0x31dA039c8Cf6eDC95fAFECb7B3E70a308128b7E0
//  npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0xc6B03Ba05Fb5E693D8b3533aa676FB4AFDd7DDc7 --src 0xd621150f4BE5b6E537f61dB2A59499F648F1B6e2
//  npx hardhat setTrustedRemote --network fantom_testnet --chain 10106 --dst 0xc6B03Ba05Fb5E693D8b3533aa676FB4AFDd7DDc7 --src 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D

//to arb_goerli
//  npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0x31dA039c8Cf6eDC95fAFECb7B3E70a308128b7E0 --src 0xc6B03Ba05Fb5E693D8b3533aa676FB4AFDd7DDc7
//  npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0x31dA039c8Cf6eDC95fAFECb7B3E70a308128b7E0 --src 0xd621150f4BE5b6E537f61dB2A59499F648F1B6e2
//  npx hardhat setTrustedRemote --network fantom_testnet --chain 10143 --dst 0x31dA039c8Cf6eDC95fAFECb7B3E70a308128b7E0 --src 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D

//to fantom_testnet
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10112 --dst 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D --src 0x31dA039c8Cf6eDC95fAFECb7B3E70a308128b7E0
//  npx hardhat setTrustedRemote --network fuji_avalanche --chain 10112 --dst 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D --src 0xc6B03Ba05Fb5E693D8b3533aa676FB4AFDd7DDc7
//  npx hardhat setTrustedRemote --network mumbai --chain 10112 --dst 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D --src 0xd621150f4BE5b6E537f61dB2A59499F648F1B6e2

export const setTrustedRemote__task = async (
    taskArgs: { chain: string; dst: string; src: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('\nRetrieving TapOFT');
    const tapContract = await getDeployment(hre, 'TapOFT');

    const path = hre.ethers.utils.solidityPack(
        ['address', 'address'],
        [taskArgs.dst, taskArgs.src],
    );
    console.log(`Setting trusted remote with path ${path}`);
    await tapContract.setTrustedRemote(taskArgs.chain, path);

    console.log('Done');
};
