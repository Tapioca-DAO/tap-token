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
import * as TAPIOCA_Z_CONFIG from '@tapiocaz/config';

export const buildFinalStackPostDepSetup_2 = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
    isTestnet: boolean,
): Promise<TapiocaMulticall.CallStruct[]> => {
    const calls: TapiocaMulticall.CallStruct[] = [];

    /**
     * Load addresses
     */
    const {
        cluster,
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
        tSglStgUsdcV2,
        ybStrategyTSglStgUsdcV2,
        // tSglSGlp,
        // ybStrategyTSglSGlp,
        // tSglDai,
        // ybStrategyTSglSDai,
    } = await loadContract__arb(hre, tag, isTestnet);

    /**
     * Sets tOB in tOLP
     */
    if (
        (await tOlp.tapiocaOptionBroker()).toLocaleLowerCase() !==
        tob.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set tOB in TOLP');
        calls.push({
            target: tOlp.address,
            allowFailure: false,
            callData: tOlp.interface.encodeFunctionData(
                'setTapiocaOptionBroker',
                [tob.address],
            ),
        });
        console.log('\t- Parameters', 'tOB', tob.address);
    }

    /**
     * Set cluster in tOB
     */
    if (
        (await tob.cluster()).toLocaleLowerCase() !==
        cluster.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set cluster in tOB');
        calls.push({
            target: tob.address,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('setCluster', [
                cluster.address,
            ]),
        });
        console.log('\t- Parameters', 'cluster', cluster.address);
    }
    /**
     * Set cluster in tOLP
     */
    if (
        (await tOlp.cluster()).toLocaleLowerCase() !==
        cluster.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set cluster in tOLP');
        calls.push({
            target: tOlp.address,
            allowFailure: false,
            callData: tOlp.interface.encodeFunctionData('setCluster', [
                cluster.address,
            ]),
        });
        console.log('\t- Parameters', 'cluster', cluster.address);
    }
    /**
     * Set cluster in twTAP
     */
    if (
        (await twTap.cluster()).toLocaleLowerCase() !==
        cluster.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set cluster in twTAP');
        calls.push({
            target: twTap.address,
            allowFailure: false,
            callData: twTap.interface.encodeFunctionData('setCluster', [
                cluster.address,
            ]),
        });
        console.log('\t- Parameters', 'cluster', cluster.address);
    }

    /**
     * Register Arb SGL GLP in TOLP
     */
    // const sglGlpYbAsset = await yieldbox.ids(
    //     1,
    //     tSglSGlp.address,
    //     ybStrategyTSglSGlp.address,
    //     0,
    // );
    const sglStgUsdcV2YbAsset = await yieldbox.ids(
        1,
        tSglStgUsdcV2.address,
        ybStrategyTSglStgUsdcV2.address,
        0,
    );

    // If SGL_GLP is not registered in TOLP, register it
    if (
        (await tOlp.sglAssetIDToAddress(sglStgUsdcV2YbAsset)).toLowerCase() !==
        tSglStgUsdcV2.address.toLowerCase()
    ) {
        console.log('[+] +Call queue: register SGL_GLP in TOLP');
        calls.push({
            target: tOlp.address,
            allowFailure: false,
            callData: tOlp.interface.encodeFunctionData('registerSingularity', [
                tSglStgUsdcV2.address,
                sglStgUsdcV2YbAsset,
                0,
            ]),
        });
        console.log(
            '\t- Parameters',
            'SGL address',
            tSglStgUsdcV2.address,
            'YB asset ID',
            sglStgUsdcV2YbAsset,
            'Weight',
            0,
        );
    }

    // /**
    //  * Register Mainnet SGL DAI in TOLP
    //  */
    // const sglDaiYbAsset = await yieldbox.ids(
    //     1,
    //     tSglDai.address,
    //     ybStrategyTSglSDai.address,
    //     0,
    // );

    // // If SGL_DAI is not registered in TOLP, register it
    // if (
    //     (await tOlp.sglAssetIDToAddress(sglDaiYbAsset)).toLowerCase() !==
    //     tSglDai.address.toLowerCase()
    // ) {
    //     console.log('[+] +Call queue: register SGL_T_SGL_DAI in TOLP');
    //     calls.push({
    //         target: tOlp.address,
    //         allowFailure: false,
    //         callData: tOlp.interface.encodeFunctionData('registerSingularity', [
    //             tSglDai.address,
    //             sglDaiYbAsset,
    //             0,
    //         ]),
    //     });
    //     console.log(
    //         '\t- Parameters',
    //         'SGL address',
    //         tSglDai.address,
    //         'YB asset ID',
    //         sglDaiYbAsset,
    //         'Weight',
    //         0,
    //     );
    // }

    if (isTestnet) {
        // // Arbitrum USDC Mock
        // const tSglUsdcMock = loadGlobalContract(
        //     hre,
        //     TAPIOCA_PROJECTS_NAME.TapiocaZ,
        //     hre.SDK.eChainId,
        //     TAPIOCA_Z_CONFIG.DEPLOYMENT_NAMES.T_SGL_USDC_MOCK_MARKET,
        //     tag,
        // );
        // const ybStrategyTSglUsdcMock = loadGlobalContract(
        //     hre,
        //     TAPIOCA_PROJECTS_NAME.TapiocaBar,
        //     hre.SDK.eChainId,
        //     TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES
        //         .YB_T_SGL_USDC_MOCK_ASSET_WITHOUT_STRATEGY,
        //     tag,
        // );
        // /**
        //  * Register Arb SGL USDC MOCK in TOLP
        //  */
        // const sglUsdcMockYbAsset = await yieldbox.ids(
        //     1,
        //     tSglUsdcMock.address,
        //     ybStrategyTSglUsdcMock.address,
        //     0,
        // );
        // // If SGL Usdc Mock is not registered in TOLP, register it
        // if (
        //     (
        //         await tOlp.sglAssetIDToAddress(sglUsdcMockYbAsset)
        //     ).toLowerCase() !== tSglUsdcMock.address.toLowerCase()
        // ) {
        //     console.log('[+] +Call queue: register SGL Usdc Mock in TOLP');
        //     calls.push({
        //         target: tOlp.address,
        //         allowFailure: false,
        //         callData: tOlp.interface.encodeFunctionData(
        //             'registerSingularity',
        //             [tSglUsdcMock.address, sglUsdcMockYbAsset, 0],
        //         ),
        //     });
        //     console.log(
        //         '\t- Parameters',
        //         'SGL address',
        //         tSglUsdcMock.address,
        //         'YB asset ID',
        //         sglUsdcMockYbAsset,
        //         'Weight',
        //         0,
        //     );
        // }
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
                '0x',
            ]),
        });
    }

    /**
     * Set twTAP in TapOFT
     */
    if (
        (await tapToken.twTap()).toLocaleLowerCase() ===
        hre.ethers.constants.AddressZero.toLocaleLowerCase()
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
                '0x',
            ]),
        });
        console.log(
            '\t- Parameters',
            'USDO',
            usdoDeployment.address,
            'USDO Oracle',
            usdoOracleDeployment.address,
            'Data',
            '0x',
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
                '0x',
            ]),
        });
        console.log(
            '\t- Parameters',
            'USDC',
            usdcAddr,
            'USDC Oracle',
            usdcOracleDeployment.address,
            'Data',
            '0x',
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
    const cluster = await hre.ethers.getContractAt(
        'Cluster',
        loadGlobalContract(
            hre,
            TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
            hre.SDK.eChainId,
            TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.CLUSTER,
            tag,
        ).address,
    );

    const tapOracleTobDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.TAP_ORACLE,
        tag,
    );

    const usdcOracleDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.USDC_SEER_CL_ORACLE,
        tag,
    );

    const usdoDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.USDO,
        tag,
    );

    const usdoOracleDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.USDO_USDC_UNI_V3_ORACLE,
        tag,
    );

    // Arbitrum SGL-GLP
    // const tSglSGlp = loadGlobalContract(
    //     hre,
    //     TAPIOCA_PROJECTS_NAME.TapiocaZ,
    //     hre.SDK.eChainId,
    //     TAPIOCA_Z_CONFIG.DEPLOYMENT_NAMES.T_SGL_GLP_MARKET,
    //     tag,
    // );
    // const ybStrategyTSglSGlp = loadGlobalContract(
    //     hre,
    //     TAPIOCA_PROJECTS_NAME.TapiocaBar,
    //     hre.SDK.eChainId,
    //     TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES
    //         .YB_T_SGL_SGLP_ASSET_WITHOUT_STRATEGY,
    //     tag,
    // );
    const tSglStgUsdcV2 = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaZ,
        hre.SDK.eChainId,
        TAPIOCA_Z_CONFIG.DEPLOYMENT_NAMES.T_SGL_STG_USDC_V2_MARKET,
        tag,
    );
    const ybStrategyTSglStgUsdcV2 = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES
            .YB_T_SGL_STG_USDC_V2_ASSET_WITHOUT_STRATEGY,
        tag,
    );

    // Mainnet tSGL-DAI
    // const tSglDai = loadGlobalContract(
    //     hre,
    //     TAPIOCA_PROJECTS_NAME.TapiocaZ,
    //     hre.SDK.eChainId,
    //     TAPIOCA_Z_CONFIG.DEPLOYMENT_NAMES.T_SGL_SDAI_MARKET,
    //     tag,
    // );
    // const ybStrategyTSglSDai = loadGlobalContract(
    //     hre,
    //     TAPIOCA_PROJECTS_NAME.TapiocaBar,
    //     hre.SDK.eChainId,
    //     TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES
    //         .YB_T_SGL_SDAI_ASSET_WITHOUT_STRATEGY,
    //     tag,
    // );

    return {
        cluster,
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
        // tSglSGlp,
        // ybStrategyTSglSGlp,
        tSglStgUsdcV2,
        ybStrategyTSglStgUsdcV2,
        // tSglDai,
        // ybStrategyTSglSDai,
    };
}
