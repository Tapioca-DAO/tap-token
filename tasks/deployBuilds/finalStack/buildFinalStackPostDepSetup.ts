import {
    TAPIOCA_PROJECTS,
    TAPIOCA_PROJECTS_NAME,
} from '@tapioca-sdk/api/config';
import { TContract } from '@tapioca-sdk/shared';
import {
    IYieldBox,
    OTAP__factory,
    TapToken__factory,
    TapiocaOptionBroker__factory,
    TapiocaOptionLiquidityProvision__factory,
    TwTAP__factory,
} from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadGlobalContract, loadLocalContract } from 'tapioca-sdk';
import { TapiocaMulticall } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';
import * as TAPIOCA_PERIPH_CONFIG from '@tapioca-periph/config';
import * as TAPIOCA_BAR_CONFIG from '@tapioca-bar/config';

export const buildFinalStackPostDepSetup_2 = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<TapiocaMulticall.CallStruct[]> => {
    const calls: TapiocaMulticall.CallStruct[] = [];

    /**
     * Load addresses
     */
    const {
        tapToken,
        oTap,
        tob,
        twTap,
        tOlp,
        yieldbox,
        usdoDeployment,
        tapOracleTobDeployment,
        usdoOracleDeployment,
        usdcOracleDeployment,
        arbSglGlpDeployment,
        ybStrategyArbSglGlpDeployment,
        ybStrategyMainnetSglDaiDeployment,
        mainnetSglDaiDeployment,
    } = await loadContract(hre, tag);

    /**
     * Register Arb SGL GLP in TOLP
     */
    const sglGlpYbAsset = await yieldbox.ids(
        1,
        arbSglGlpDeployment.address,
        ybStrategyArbSglGlpDeployment.address,
        0,
    );

    // If SGL_GLP is not registered in TOLP, register it
    if (
        (await tOlp.sglAssetIDToAddress(sglGlpYbAsset)).toLowerCase() !==
        arbSglGlpDeployment.address.toLowerCase()
    ) {
        console.log('[+] +Call queue: register SGL_GLP in TOLP');
        calls.push({
            target: tOlp.address,
            allowFailure: false,
            callData: tOlp.interface.encodeFunctionData('registerSingularity', [
                arbSglGlpDeployment.address,
                sglGlpYbAsset,
                0,
            ]),
        });
        console.log(
            '\t- Parameters',
            'SGL address',
            arbSglGlpDeployment.address,
            'YB asset ID',
            sglGlpYbAsset,
            'Weight',
            0,
        );
    }

    /**
     * Register Mainnet SGL DAI in TOLP
     */
    const sglDaiYbAsset = await yieldbox.ids(
        1,
        mainnetSglDaiDeployment.address,
        ybStrategyMainnetSglDaiDeployment.address,
        0,
    );

    // If SGL_DAI is not registered in TOLP, register it
    if (
        (await tOlp.sglAssetIDToAddress(sglDaiYbAsset)).toLowerCase() !==
        mainnetSglDaiDeployment.address.toLowerCase()
    ) {
        console.log('[+] +Call queue: register SGL_DAI in TOLP');
        calls.push({
            target: tOlp.address,
            allowFailure: false,
            callData: tOlp.interface.encodeFunctionData('registerSingularity', [
                mainnetSglDaiDeployment.address,
                sglDaiYbAsset,
                0,
            ]),
        });
        console.log(
            '\t- Parameters',
            'SGL address',
            mainnetSglDaiDeployment.address,
            'YB asset ID',
            sglDaiYbAsset,
            'Weight',
            0,
        );
    }

    /**
     * Set tOB as minter for TapOFT
     */

    if (
        (await tapToken.minter()).toLocaleLowerCase() !==
        tob.address.toLocaleLowerCase()
    ) {
        console.log('[+] Setting tOB as minter for TapToken');
        calls.push({
            target: tapToken.address,
            allowFailure: false,
            callData: tapToken.interface.encodeFunctionData('setMinter', [
                tob.address,
            ]),
        });
        console.log('\t- Parameters', 'tOB', tob.address);
    }

    /**
     * Set tOB Broker role for tOB on oTAP and init TapToken emissions
     */
    if (
        (await oTap.broker()).toLocaleLowerCase() !==
        tob.address.toLocaleLowerCase()
    ) {
        console.log(
            '[+] +Call queue: tOB init(): oTAP broker claim and TapToken emission',
        );
        calls.push({
            target: tob.address,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('init'),
        });
    }

    /**
     * Set TAP Oracle in tOB
     */
    if (
        (await tob.tapOracle()).toLocaleLowerCase() !==
        tapOracleTobDeployment.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set TapToken in TapiocaOptionBroker');
        calls.push({
            target: tob.address,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('setTapOracle', [
                tapOracleTobDeployment.address,
                '0x00',
            ]),
        });
    }

    /**
     * Set twTAP in TapOFT
     */
    if (
        (await tapToken.twTap()).toLocaleLowerCase() !==
        twTap.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set twTAP in TapToken');
        calls.push({
            target: tapToken.address,
            allowFailure: false,
            callData: tapToken.interface.encodeFunctionData('setTwTAP', [
                twTap.address,
            ]),
        });
    }

    /**
     * Set USDO as payment token in tOB if not set
     */
    if (
        (
            await tob.paymentTokens(usdoDeployment.address)
        ).oracle.toLocaleLowerCase() !==
        usdoOracleDeployment.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set USDO as payment token in tOB');
        calls.push({
            target: tob.address,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('setPaymentToken', [
                usdoDeployment.address,
                usdoOracleDeployment.address,
                '0x00',
            ]),
        });
        console.log(
            '\t- Parameters',
            'USDO',
            usdoDeployment.address,
            'USDO Oracle',
            usdoOracleDeployment.address,
            'Data',
            '0x00',
        );
    }

    /**
     * Set USDC as payment token in tOB if not set
     */
    const usdcAddr = DEPLOY_CONFIG.MISC[hre.SDK.eChainId]!.USDC;
    if (
        (await tob.paymentTokens(usdcAddr)).oracle.toLocaleLowerCase() !==
        usdcOracleDeployment.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set USDO as payment token in tOB');
        calls.push({
            target: tob.address,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('setPaymentToken', [
                usdcAddr,
                usdcOracleDeployment.address,
                '0x00',
            ]),
        });
        console.log(
            '\t- Parameters',
            'USDC',
            usdcAddr,
            'USDC Oracle',
            usdcOracleDeployment.address,
            'Data',
            '0x00',
        );
    }

    /**
     * Set USDO as reward token in TwTap if not set
     */
    if (
        (await twTap.rewardTokenIndex(usdoDeployment.address)).toNumber() === 0
    ) {
        console.log('[+] +Call queue: set USDO as reward token in TwTap');
        calls.push({
            target: twTap.address,
            allowFailure: false,
            callData: twTap.interface.encodeFunctionData('addRewardToken', [
                usdoDeployment.address,
            ]),
        });
        console.log('\t- Parameters', 'USDO', usdoDeployment.address);
    }

    return calls;
};

async function loadContract__generic(
    hre: HardhatRuntimeEnvironment,
    tag: string,
) {}

async function loadContract__arb(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    isTestnet: boolean,
) {
    const tapToken = TapToken__factory.connect(
        loadLocalContract(
            hre,
            hre.SDK.eChainId,
            DEPLOYMENT_NAMES.TAP_TOKEN,
            tag,
        ).address,
        hre.ethers.provider.getSigner(),
    );
    const twTap = TwTAP__factory.connect(
        loadLocalContract(hre, hre.SDK.eChainId, DEPLOYMENT_NAMES.TWTAP, tag)
            .address,
        hre.ethers.provider.getSigner(),
    );
    const tob = TapiocaOptionBroker__factory.connect(
        loadLocalContract(
            hre,
            hre.SDK.eChainId,
            DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER,
            tag,
        ).address,
        hre.ethers.provider.getSigner(),
    );
    const oTap = OTAP__factory.connect(
        loadLocalContract(hre, hre.SDK.eChainId, DEPLOYMENT_NAMES.OTAP, tag)
            .address,
        hre.ethers.provider.getSigner(),
    );
    const tOlp = TapiocaOptionLiquidityProvision__factory.connect(
        loadLocalContract(
            hre,
            hre.SDK.eChainId,
            DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
            tag,
        ).address,
        hre.ethers.provider.getSigner(),
    );
    const yieldbox = await hre.ethers.getContractAt(
        'IYieldBox',
        loadGlobalContract(
            hre,
            TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
            hre.SDK.eChainId,
            TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.YIELDBOX,
            tag,
        ).address,
    );

    const tapOracleTobDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.TOB_TAP_OPTION_ORACLE,
        tag,
    ).address;

    const usdcOracleDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.USDC_SEER_CL_ORACLE,
        tag,
    ).address;

    const usdoDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.USDO,
        tag,
    ).address;

    const usdoOracleDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.USDO_USDC_UNI_V3_ORACLE,
        tag,
    ).address;

    // Arbitrum SGL-GLP
    const arbSglGlpDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.SGL_S_GLP_MARKET,
        tag,
    ).address;
    const ybStrategyArbSglGlpDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        isTestnet
            ? TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.YB_SGLP_ASSET_WITHOUT_STRATEGY
            : TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.YB_SGLP_ASSET_WITH_STRATEGY,
        tag,
    ).address;

    return {
        tapToken,
        twTap,
        tob,
        oTap,
        tOlp,
        yieldbox,
        usdoDeployment,
        tapOracleTobDeployment,
        usdoOracleDeployment,
        usdcOracleDeployment,
        arbSglGlpDeployment,
        ybStrategyArbSglGlpDeployment,
        mainnetSglDaiDeployment,
        ybStrategyMainnetSglDaiDeployment,
    };
}

async function loadContract__eth(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    isTestnet: boolean,
) {
    // Mainnet SGL-DAI
    const mainnetSglDaiDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.SGL_S_DAI_MARKET,
        tag,
    ).address;
    const ybStrategyMainnetSglDaiDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        isTestnet
            ? TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.YB_SDAI_ASSET_WITHOUT_STRATEGY
            : TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.YB_SDAI_ASSET_WITH_STRATEGY,
        tag,
    ).address;
}
