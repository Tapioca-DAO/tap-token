import { EChainID } from '@tapioca-sdk/api/config';
import { FeeAmount } from '@uniswap/v3-sdk';

// Name of the contract deployments to be used in the deployment scripts and saved in the deployments file
export const DEPLOYMENT_NAMES = {
    // Pre-LBP
    LTAP: 'LTAP',
    LBP: 'LBP',
    // Post-LBP
    VESTING_CONTRIBUTORS: 'VESTING_CONTRIBUTORS',
    VESTING_EARLY_SUPPORTERS: 'VESTING_EARLY_SUPPORTERS',
    VESTING_SUPPORTERS: 'VESTING_SUPPORTERS',
    TAP_TOKEN_SENDER_MODULE: 'TAP_TOKEN_SENDER_MODULE',
    TAP_TOKEN_RECEIVER_MODULE: 'TAP_TOKEN_RECEIVER_MODULE',
    TAP_TOKEN: 'TAP_TOKEN',
    TAP_ORACLE: 'TAP_ORACLE',
    TOB_TAP_ORACLE: 'TOB_TAP_ORACLE',
    AOTAP: 'AOTAP',
    AIRDROP_BROKER: 'AIRDROP_BROKER',
    TAP_WETH_UNI_V3_POOL: 'TAP_WETH_UNI_V3_POOL',
    USDC_SEER_CL_ORACLE: 'USDC_SEER_CL_ORACLE',
    EXT_EXEC: 'EXT_EXEC',
    // Final
    TAPIOCA_OPTION_LIQUIDITY_PROVISION: 'TAPIOCA_OPTION_LIQUIDITY_PROVISION',
    TAPIOCA_OPTION_BROKER: 'TAPIOCA_OPTION_BROKER',
    OTAP: 'OTAP',
    TWTAP: 'TWTAP',
    YB_SGL_ARB_GLP_STRATEGY: 'YB_SGL_ARB_GLP_STRATEGY',
    YB_SGL_MAINNET_DAI_STRATEGY: 'YB_SGL_MAINNET_DAI_STRATEGY',
    // TO MOVE
    ARBITRUM_SGL_GLP: 'ARBITRUM_SGL_GLP', // TODO move to tapioca bar repo name config
    MAINNET_SGL_DAI: 'MAINNET_SGL_DAI', // TODO move to tapioca bar repo name config
    PEARLMIT: 'PEARLMIT', // TODO move to tapioca periph repo name config
    CLUSTER: 'CLUSTER', // TODO move to tapioca periph repo name config
};

type TPostLbp = {
    [key in EChainID]?: {
        TAP: {
            DAO_ADDRESS: string;
        };
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY: string;
        };
        TAP_ORACLE: {
            NAME: string;
            DESCRIPTION: string;
            ETH_USD_CHAINLINK: string;
            WETH_USDC_UNI_POOL: string;
        };
        PCNFT: {
            ADDRESS: string;
        };
        VESTING: {
            CONTRIBUTORS_CLIFF: number;
            CONTRIBUTORS_PERIOD: number;
            EARLY_SUPPORTERS_CLIFF: number;
            EARLY_SUPPORTERS_PERIOD: number;
            SUPPORTERS_CLIFF: number;
            SUPPORTERS_PERIOD: number;
        };
        UNISWAP_POOL: {
            TAP_AMOUNT: number;
            WETH_AMOUNT: number;
            FEE_AMOUNT: FeeAmount;
        };
    };
};

const POST_LBP: TPostLbp = {
    [EChainID.ARBITRUM]: {
        TAP: {
            DAO_ADDRESS: '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
        },
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY:
                '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
        },
        TAP_ORACLE: {
            NAME: 'TAP/USD',
            DESCRIPTION:
                'TAP/USD price feed. Using TAP/WETH UNI, WETH/USD Chainlink and TAP/USD Chainlink.',
            ETH_USD_CHAINLINK: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612',
            WETH_USDC_UNI_POOL: '0xC6962004f452bE9203591991D15f6b388e09E8D0', // 500 FeeAmount
        },
        PCNFT: {
            ADDRESS: '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
        },
        VESTING: {
            // Contributors
            CONTRIBUTORS_CLIFF: 31104000, // 12 months cliff
            CONTRIBUTORS_PERIOD: 93312000, // 36 months vesting
            // Early supporters
            EARLY_SUPPORTERS_CLIFF: 0,
            EARLY_SUPPORTERS_PERIOD: 62208000, // 24 months vesting
            // Supporters
            SUPPORTERS_CLIFF: 0,
            SUPPORTERS_PERIOD: 46656000, // 18 months vesting
        },
        UNISWAP_POOL: {
            TAP_AMOUNT: 0,
            WETH_AMOUNT: 0,
            FEE_AMOUNT: FeeAmount.MEDIUM,
        },
    },
};
POST_LBP[EChainID.ARBITRUM_SEPOLIA] = POST_LBP[EChainID.ARBITRUM]; // Copy from Arbitrum
POST_LBP[EChainID.SEPOLIA] = POST_LBP[EChainID.ARBITRUM]; // Copy from Arbitrum
POST_LBP['31337' as EChainID] = POST_LBP[EChainID.ARBITRUM]; // Copy from Arbitrum

type TFinal = {
    [key in EChainID]?: {
        TOLP: {
            EPOCH_DURATION: number;
        };
        TOB: {
            PAYMENT_TOKEN_ADDRESS: string;
        };
    };
};

const FINAL: TFinal = {
    [EChainID.ARBITRUM]: {
        TOLP: {
            EPOCH_DURATION: 604800, // 7 days
        },
        TOB: {
            PAYMENT_TOKEN_ADDRESS: '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
        },
    },
};
FINAL[EChainID.ARBITRUM_SEPOLIA] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum
FINAL[EChainID.SEPOLIA] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum
FINAL['31337' as EChainID] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum

type TMisc = {
    [key in EChainID]?: {
        CL_SEQUENCER: string;
        WETH: string;
        USDC: string;
    };
};
const MISC: TMisc = {
    [EChainID.ARBITRUM]: {
        CL_SEQUENCER: '0xFdB631F5EE196F0ed6FAa767959853A9F217697D', // Arbitrum mainnet ChainLink sequencer uptime feed
        WETH: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
        USDC: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
    },
};
MISC[EChainID.ARBITRUM_SEPOLIA] = MISC[EChainID.ARBITRUM]; // Copy from Arbitrum
MISC[EChainID.SEPOLIA] = MISC[EChainID.ARBITRUM]; // Copy from Arbitrum

const UNISWAP = {
    NONFUNGIBLE_POSITION_MANAGER: '0xc36442b4a4522e871399cd717abdd847ab11fe88',
    V3_FACTORY: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
};

export const DEPLOY_CONFIG = {
    POST_LBP,
    FINAL,
    MISC,
    UNISWAP,
};
