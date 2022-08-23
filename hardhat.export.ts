import * as dotenv from 'dotenv';

import { HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-vyper';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-deploy';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-contract-sizer';
import '@primitivefi/hardhat-dodoc';
import 'solidity-coverage';
// import 'hardhat-gas-reporter';

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.9',
        settings: {
            optimizer: {
                enabled: true,
                runs: 100,
            },
        },
    },
    vyper: {
        compilers: [{ version: '0.2.8' }],
    },
    namedAccounts: {
        deployer: 0,
        minter: 1,
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
            tags: ['testnet'],
        },
        mainnet: {
            gasMultiplier: 2,
            live: true,
            url: 'https://andromeda.metis.io/?owner=1088',
            chainId: 1088,
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
        },
    },
    etherscan: {
        apiKey: {
            rinkeby: process.env.RINKEBY_KEY ?? '',
        },
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
};

export default config;
