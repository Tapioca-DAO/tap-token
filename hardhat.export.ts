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

dotenv.config();

const config: HardhatUserConfig & { vyper: any; dodoc: any } = {
    solidity: {
        compilers: [
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
        compilers: [{ version: '0.2.8' }],
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
        testnet: {
            gasMultiplier: 2,
            url: 'https://stardust.metis.io/?owner=588',
            chainId: 588,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            tags: ['testing'],
        },
        rinkeby: {
            gasMultiplier: 1,
            url: process.env.RINKEBY ?? 'https://rinkeby.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
            chainId: 4,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            tags: ['testing'],
        },
        mumbai: {
            gasMultiplier: 1,
            url: 'https://matic-mumbai.chainstacklabs.com',
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            chainId: 80001,
            tags: ['testing'],
        },
        arbitrum_testnet: {
            url: 'https://rinkeby.arbitrum.io/rpc',
            chainId: 421611,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            tags: ['testing'],
        },
        fantom_testnet: {
            url: 'https://rpc.testnet.fantom.network/',
            chainId: 0xfa2,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            tags: ['testing'],
        },
        mainnet: {
            gasMultiplier: 2,
            live: true,
            url: 'https://andromeda.metis.io/?owner=1088',
            chainId: 1088,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            tags: ['eth'],
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_KEY ?? '',
        customChains: [
            {
                network: 'rinkeby',
                chainId: 4,
                urls: {
                    apiURL: 'https://api-rinkeby.etherscan.io/api',
                    browserURL: 'https://rinkeby.etherscan.io',
                },
            },
        ],
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
        ],
    },
    typechain: { 
        outDir: 'typechain',
        target: 'ethers-v5',
    },
};

export default config;
