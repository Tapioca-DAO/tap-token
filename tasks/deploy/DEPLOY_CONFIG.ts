import { EChainID } from '@tapioca-sdk/api/config';

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
    AOTAP: 'AOTAP',
    AIRDROP_BROKER: 'AIRDROP_BROKER',
    // Final
    TAPIOCA_OPTION_LIQUIDITY_PROVISION: 'TAPIOCA_OPTION_LIQUIDITY_PROVISION',
    TAPIOCA_OPTION_BROKER: 'TAPIOCA_OPTION_BROKER',
    OTAP: 'OTAP',
    TWTAP: 'TWTAP',
    YB_SGL_ARB_GLP_STRATEGY: 'YB_SGL_ARB_GLP_STRATEGY',
    YB_SGL_MAINNET_DAI_STRATEGY: 'YB_SGL_MAINNET_DAI_STRATEGY',
    ARBITRUM_SGL_GLP: 'ARBITRUM_SGL_GLP', // TODO move to tapioca bar repo name config
    MAINNET_SGL_DAI: 'MAINNET_SGL_DAI', // TODO move to tapioca bar repo name config
};

const POST_LBP = {
    [EChainID.ARBITRUM]: {
        TAP: {
            LBP_ADDRESS: '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
            DAO_ADDRESS: '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
        },
        ADB: {
            PAYMENT_TOKEN_BENEFICIARY:
                '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
            USDC_PAYMENT_TOKEN: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
        },
        TAP_ORACLE: {
            TAP_USDC_LP_ADDRESS: '0x0',
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
    },
};

const FINAL = {
    [EChainID.ARBITRUM]: {
        TOLP: {
            EPOCH_DURATION: 604800, // 7 days
        },
        TOB: {
            PAYMENT_TOKEN_ADDRESS: '0x464570adA09869d8741132183721B4f0769a0287', // TODO replace by real address
        },
    },
};

const MISC = {
    [EChainID.ARBITRUM]: {
        MISC: {
            CL_SEQUENCER: '0xFdB631F5EE196F0ed6FAa767959853A9F217697D', // Arbitrum mainnet ChainLink sequencer uptime feed
        },
    },
};

export const DEPLOY_CONFIG = {
    POST_LBP,
    FINAL,
    MISC,
};
