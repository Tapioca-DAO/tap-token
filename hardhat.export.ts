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
import SDK from 'tapioca-sdk';
import { HttpNetworkConfig } from 'hardhat/types';

dotenv.config();

let supportedChains: { [key: string]: HttpNetworkConfig } = SDK.API.utils.getSupportedChains().reduce(
    (sdkChains, chain) => ({
        ...sdkChains,
        [chain.name]: <HttpNetworkConfig>{
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            live: true,
            url: chain.rpc.replace('<api_key>', process.env.ALCHEMY_KEY),
            gasMultiplier: chain.tags.includes('testnet') ? 2 : 1,
            chainId: Number(chain.chainId),
        },
    }),
    {},
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
        //testnets
        arbitrum_goerli: {
            url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
            accounts: [process.env.PRIVATE_KEY!],
            chainId: 421613,
            lzChainId: '10143',
        },
        mumbai: {
            url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
            accounts: [process.env.PRIVATE_KEY!],
        },
        goerli: supportedChains['goerli'],
        bnb_testnet: supportedChains['bnb_testnet'],
        fuji_avalanche: supportedChains['fuji_avalanche'],
        //mumbai: supportedChains['mumbai'],
        fantom_testnet: supportedChains['fantom_testnet'],
        // arbitrum_goerli: supportedChains['arbitrum_goerli'],
        optimism_goerli: supportedChains['optimism_goerli'],
        harmony_testnet: supportedChains['harmony_testnet'],

        //mainnets
        ethereum: supportedChains['ethereum'],
        bnb: supportedChains['bnb'],
        avalanche: supportedChains['avalanche'],
        matic: supportedChains['polygon'],
        arbitrum: supportedChains['arbitrum'],
        optimism: supportedChains['optimism'],
        fantom: supportedChains['fantom'],
        harmony: supportedChains['harmony'],
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_KEY,
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
