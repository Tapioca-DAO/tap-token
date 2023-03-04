import * as dotenv from 'dotenv';

import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-vyper';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import '@primitivefi/hardhat-dodoc';
import 'typechain';
import '@typechain/hardhat';
import 'hardhat-tracer';

import SDK from 'tapioca-sdk';
import { HttpNetworkConfig } from 'hardhat/types';

dotenv.config();

type TNetwork = ReturnType<typeof SDK.API.utils.getSupportedChains>[number]['name'];
const supportedChains = SDK.API.utils.getSupportedChains().reduce(
    (sdkChains, chain) => ({
        ...sdkChains,
        [chain.name]: <HttpNetworkConfig>{
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            live: true,
            url: chain.rpc.replace('<api_key>', process.env.ALCHEMY_API_KEY),
            gasMultiplier: chain.tags.includes('testnet') ? 2 : 1,
            chainId: Number(chain.chainId),
            tags: [...chain.tags],
        },
    }),
    {} as { [key in TNetwork]: HttpNetworkConfig },
);

const config: HardhatUserConfig & { vyper: any; dodoc: any } = {
    solidity: {
        compilers: [
            {
                version: '0.4.24',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100,
                    },
                },
            },
            {
                version: '0.8.9',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100,
                    },
                },
            },
        ],
    },
    vyper: {
        compilers: [{ version: '0.2.15' }, { version: '0.2.8' }, { version: '0.3.1' }, { version: '0.3.3' }],
    },
    namedAccounts: {
        deployer: 0,
    },
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
            accounts: {
                count: 5,
            },
        },
        ...supportedChains,
    },
    etherscan: {
        apiKey: {
            goerli: process.env.BLOCKSCAN_KEY ?? '',
            arbitrumGoerli: process.env.ARBITRUM_GOERLI_KEY ?? '',
        },
        customChains: [],
    },
    mocha: {
        timeout: 4000000,
    },
    dodoc: {
        runOnCompile: false,
        freshOutput: true,
        exclude: [
            //doesn't work with Vyper contracts
            'VeTap',
            'FeeDistributor',
            'GaugeController',
            'BoostV2',
            'DelegationProxy',
            'VotingEscrowDelegation',
        ],
    },
    typechain: {
        outDir: 'typechain',
        target: 'ethers-v5',
    },
};

export default config;
