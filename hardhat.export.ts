import * as dotenv from 'dotenv';

// Plugins
import { HardhatUserConfig, extendEnvironment } from 'hardhat/config';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-foundry';
import '@primitivefi/hardhat-dodoc';
import 'hardhat-contract-sizer';
import '@typechain/hardhat';
import 'hardhat-tracer';
import fs from 'fs';

// Utils
import 'tapioca-sdk'; // Use directly the un-compiled code, no need to wait for the tarball to be published.
import SDK from 'tapioca-sdk';
import { HttpNetworkConfig, HttpNetworkUserConfig } from 'hardhat/types';
import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';

declare global {
    // eslint-disable-next-line @typescript-eslint/no-namespace
    namespace NodeJS {
        interface ProcessEnv {
            ALCHEMY_API_KEY: string;
            ENV: string;
        }
    }
}

const networkArg = process.argv.findIndex((c) => c === '--network');
let networkName = 'localhost';

if (networkArg !== -1) {
    networkName = process.argv[networkArg + 1]; // Get the network name
} else {
    console.log('[!] No network specified, using localhost as default.');
}

// dotenv loading can not load `export` env vars for some reasons
const path = `.env/${networkName}.env`;

if (fs.existsSync(path)) {
    dotenv.config({ path });
} else {
    throw new Error(
        '[-] env vars not loaded, please specify a network with --network <network> and create its file in .env/<network>.env',
    );
}

type TNetwork = ReturnType<
    typeof SDK.API.utils.getSupportedChains
>[number]['name'];
const supportedChains = SDK.API.utils.getSupportedChains().reduce(
    (sdkChains, chain) => ({
        ...sdkChains,
        [chain.name]: <HttpNetworkUserConfig>{
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            live: true,
            url: chain.rpc.replace('<api_key>', process.env.ALCHEMY_API_KEY),
            gasMultiplier: chain.tags[0] === 'testnet' ? 2 : 1,
            chainId: Number(chain.chainId),
            tags: [...chain.tags],
        },
    }),
    {} as { [key in TNetwork]: HttpNetworkConfig },
);

const config: HardhatUserConfig & { dodoc: any } = {
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
                version: '0.8.22',
                settings: {
                    evmVersion: 'paris', // Latest before Shanghai
                    optimizer: {
                        enabled: true,
                        runs: 9999,
                    },
                },
            },
        ],
    },
    paths: {
        artifacts: './gen/artifacts',
        cache: './gen/cache',
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
    SDK: { project: TAPIOCA_PROJECTS_NAME.TapToken },
    etherscan: {
        apiKey: {
            sepolia: process.env.SCAN_API_KEY ?? '',
            arbitrumSepolia: process.env.SCAN_API_KEY ?? '',
            optimismSepolia: process.env.SCAN_API_KEY ?? '',
            avalancheFujiTestnet: process.env.SCAN_API_KEY ?? '',
            bscTestnet: process.env.SCAN_API_KEY ?? '',
            polygonMumbai: process.env.SCAN_API_KEY ?? '',
            ftmTestnet: process.env.SCAN_API_KEY ?? '',
        },
        customChains: [
            {
                network: 'arbitrumSepolia',
                chainId: 421614,
                urls: {
                    apiURL: 'https://api-sepolia.arbiscan.io/api',
                    browserURL: 'https://sepolia.arbiscan.io/',
                },
            },
            {
                network: 'optimismSepolia',
                chainId: 11155420,
                urls: {
                    apiURL: 'https://api-sepolia-optimistic.etherscan.io/',
                    browserURL: 'https://sepolia-optimism.etherscan.io/',
                },
            },
        ],
    },
    mocha: {
        timeout: 4000000,
    },
    dodoc: {
        runOnCompile: false,
        freshOutput: false,
        outputDir: 'gen/docs',
    },
    typechain: {
        outDir: 'gen/typechain',
        target: 'ethers-v5',
    },
};

export default config;

extendEnvironment((hre) => {
    // remove hardhat core tasks
    delete hre.tasks['gas-reporter:merge'];
    delete hre.tasks['export-artifacts'];
    delete hre.tasks['size-contracts'];
    delete hre.tasks['init-foundry'];
    delete hre.tasks.coverage;
    delete hre.tasks.sourcify;
    delete hre.tasks.accounts;
    delete hre.tasks.flatten;
    delete hre.tasks.deploy;
    delete hre.tasks.export;
    delete hre.tasks.export;
    delete hre.tasks.check;
    delete hre.tasks.test;
    delete hre.tasks.node;
    delete hre.tasks.run;
});
