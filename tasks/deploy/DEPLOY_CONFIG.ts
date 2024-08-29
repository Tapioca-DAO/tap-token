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
    TAP_TOKEN_HELPER: 'TAP_TOKEN_HELPER',
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
};

type TPostLbp = {
    [key in EChainID]?: {
        TAP: {
            DAO_ADDRESS: string;
        };
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY: string;
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
    };
};

const POST_LBP: TPostLbp = {
    [EChainID.ARBITRUM]: {
        TAP: {
            DAO_ADDRESS: '0x7A3B760AcFaB78f6bc6a1AD80F7743f5bA0513Dc',
        },
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY:
                '0x7A3B760AcFaB78f6bc6a1AD80F7743f5bA0513Dc', // MULTISIG
        },
        PCNFT: {
            ADDRESS: '0xA805E1b42590be85D2c74E09c0e1c1B6063Ea1A7',
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
    },
    [EChainID.MAINNET]: {
        TAP: {
            DAO_ADDRESS: '0x7A3B760AcFaB78f6bc6a1AD80F7743f5bA0513Dc',
        },
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY:
                '0x7A3B760AcFaB78f6bc6a1AD80F7743f5bA0513Dc', // MULTISIG
        },
        PCNFT: {
            ADDRESS: '0xA805E1b42590be85D2c74E09c0e1c1B6063Ea1A7',
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
    },
    [EChainID.ARBITRUM_SEPOLIA]: {
        TAP: {
            DAO_ADDRESS: '',
        },
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY: '',
        },
        PCNFT: {
            ADDRESS: '0x52b4B758d0dC4039747a2BD52F87e4448511158d',
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
    },
    [EChainID.BASE_SEPOLIA]: {
        TAP: {
            DAO_ADDRESS: '',
        },
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY: '',
        },
        PCNFT: {
            ADDRESS: '0x52b4B758d0dC4039747a2BD52F87e4448511158d',
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
    },
    [EChainID.FUJI_AVALANCHE]: {
        PCNFT: {
            ADDRESS: '',
        },
        TAP: {
            DAO_ADDRESS: '',
        },
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY: '',
        },
        VESTING: {
            CONTRIBUTORS_CLIFF: 0,
            CONTRIBUTORS_PERIOD: 0,
            EARLY_SUPPORTERS_CLIFF: 0,
            EARLY_SUPPORTERS_PERIOD: 0,
            SUPPORTERS_CLIFF: 0,
            SUPPORTERS_PERIOD: 0,
        },
    },
};
// TESTNET ONLY
POST_LBP[EChainID.SEPOLIA] = POST_LBP[EChainID.ARBITRUM]; // Copy from Arbitrum
POST_LBP[EChainID.OPTIMISM_SEPOLIA] = POST_LBP[EChainID.ARBITRUM]; // Copy from Arbitrum
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
            PAYMENT_TOKEN_ADDRESS: '0x7A3B760AcFaB78f6bc6a1AD80F7743f5bA0513Dc', // MULTISIG
        },
    },
    [EChainID.MAINNET]: {
        TOLP: {
            EPOCH_DURATION: 604800, // 7 days
        },
        TOB: {
            PAYMENT_TOKEN_ADDRESS: '0x7A3B760AcFaB78f6bc6a1AD80F7743f5bA0513Dc', // MULTISIG
        },
    },
};
FINAL[EChainID.ARBITRUM_SEPOLIA] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum
FINAL[EChainID.FUJI_AVALANCHE] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum
FINAL[EChainID.SEPOLIA] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum
FINAL[EChainID.OPTIMISM_SEPOLIA] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum
FINAL[EChainID.BASE_SEPOLIA] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum
FINAL['31337' as EChainID] = FINAL[EChainID.ARBITRUM]; // Copy from Arbitrum

type TMisc = {
    [key in EChainID]?: {
        CL_SEQUENCER: string;
        WETH: string;
        USDC: string;
        NONFUNGIBLE_POSITION_MANAGER: string;
        V3_FACTORY: string;
    };
};
const MISC: TMisc = {
    [EChainID.ARBITRUM]: {
        CL_SEQUENCER: '0xFdB631F5EE196F0ed6FAa767959853A9F217697D', // Arbitrum mainnet ChainLink sequencer uptime feed
        WETH: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
        USDC: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
        NONFUNGIBLE_POSITION_MANAGER:
            '0xc36442b4a4522e871399cd717abdd847ab11fe88',
        V3_FACTORY: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
    },
    [EChainID.ARBITRUM_SEPOLIA]: {
        CL_SEQUENCER: '0x',
        WETH: '0x2EAe4fbc552fE35C1D3Df2B546032409bb0E431E', // Locally deployed WETH9 Mock
        USDC: '0xF72c2794A9Ea95C5a8CD033999F319B15723E751', // Locally deployed USDC Mock
        NONFUNGIBLE_POSITION_MANAGER:
            '0xFd1a7CA61e49703da3618999B2EEdc0E79476759',
        V3_FACTORY: '0x76D8F1D83716bcd0f811449a76Fc2B3E3ef98454',
    },
    [EChainID.BASE_SEPOLIA]: {
        CL_SEQUENCER: '0x',
        WETH: '',
        USDC: '',
        NONFUNGIBLE_POSITION_MANAGER:
            '0xf77d418B10642d497755a42F7EBD5578d7041bC9',
        V3_FACTORY: '0xDF474d2667bbD4488a7CbDEc1A27d0C667123AcF',
    },
    [EChainID.BERACHAIN_TESTNET]: {
        CL_SEQUENCER: '0x',
        WETH: '',
        USDC: '',
        NONFUNGIBLE_POSITION_MANAGER:
            '0xDF474d2667bbD4488a7CbDEc1A27d0C667123AcF',
        V3_FACTORY: '0x7d91FCA53809e393eCa64a09785330bc28DF0639',
    },
};

export const DEPLOY_CONFIG = {
    POST_LBP,
    FINAL,
    MISC,
};
