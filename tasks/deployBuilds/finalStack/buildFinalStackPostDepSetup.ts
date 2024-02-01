import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { EChainID, TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { TContract } from '@tapioca-sdk/shared';
import { IYieldBox } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TapiocaMulticall } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';

export const buildFinalStackPostDepSetup_1 = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<TapiocaMulticall.CallStruct[]> => {
    let calls: TapiocaMulticall.CallStruct[] = [];
    const signer = (await hre.ethers.getSigners())[0];

    /**
     * Load addresses
     */
    const {
        yieldbox,
        arbSglGlpDeployment,
        ybStrategyArbSglGlpDeployment,
        ybStrategyMainnetSglDaiDeployment,
        mainnetSglDaiDeployment,
    } = await loadContract(hre, tag);

    /**
     * Register Arb SGL GLP in YieldBox
     */
    calls = [
        ...calls,
        ...(await registerAssetInYieldbox(
            hre,
            arbSglGlpDeployment,
            ybStrategyArbSglGlpDeployment,
            yieldbox,
            signer,
        )),
    ];

    /**
     * Register Mainnet SGL DAI in YieldBox
     */
    calls = [
        ...calls,
        ...(await registerAssetInYieldbox(
            hre,
            mainnetSglDaiDeployment,
            ybStrategyMainnetSglDaiDeployment,
            yieldbox,
            signer,
        )),
    ];

    /**
     * Deploy TapTokenOptionOracle
     */

    return calls;
};

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
     * Set tOB Broker role for tOB on oTAP
     */
    if (
        (await oTap.broker()).toLocaleLowerCase() !==
        tob.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: oTAP broker claim');
        calls.push({
            target: tob.address,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('oTAPBrokerClaim'),
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
        usdoDeployment.address.toLocaleLowerCase()
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
            'USDO',
            usdcAddr,
            'USDO Oracle',
            usdcOracleDeployment.address,
            'Data',
            '0x00',
        );
    }

    return calls;
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const tapToken = await hre.ethers.getContractAt(
        'TapToken',
        getContract(hre, tag, DEPLOYMENT_NAMES.TAP_TOKEN).address,
    );
    const twTap = await hre.ethers.getContractAt(
        'TwTAP',
        getContract(hre, tag, DEPLOYMENT_NAMES.TWTAP).address,
    );
    const tob = await hre.ethers.getContractAt(
        'TapiocaOptionBroker',
        getContract(hre, tag, DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER).address,
    );
    const oTap = await hre.ethers.getContractAt(
        'OTAP',
        getContract(hre, tag, DEPLOYMENT_NAMES.OTAP).address,
    );
    const tOlp = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        getContract(
            hre,
            tag,
            DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
        ).address,
    );
    const yieldbox = await hre.ethers.getContractAt(
        'IYieldBox',
        getGlobalDeployment(
            hre,
            tag,
            TAPIOCA_PROJECTS_NAME.YieldBox,
            hre.SDK.eChainId,
            'YIELDBOX', // TODO replace by YB NAME CONFIG
        ).address,
    );

    const usdcOracleDeployment = getContract(
        hre,
        tag,
        DEPLOYMENT_NAMES.USDC_USDC_CL_POOl,
    );

    const usdoDeployment = getGlobalDeployment(
        hre,
        tag,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        'USDO', // TODO replace by BAR NAME CONFIG
    );
    const usdoOracleDeployment = getGlobalDeployment(
        hre,
        tag,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        'USDO_UNI_POOL', // TODO replace by BAR NAME CONFIG
    );

    // Arbitrum SGL-GLP
    const arbSglGlpDeployment = getGlobalDeployment(
        hre,
        tag,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        'ARB_SGL_GLP', // TODO replace by BAR NAME CONFIG
    );
    const ybStrategyArbSglGlpDeployment = getContract(
        hre,
        tag,
        DEPLOYMENT_NAMES.YB_SGL_ARB_GLP_STRATEGY,
    );

    // Mainnet SGL-DAI
    const mainnetSglDaiDeployment = getGlobalDeployment(
        hre,
        tag,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        'TOFT_MAINNET_SGL_DAI', // TODO replace by TapiocaZ NAME CONFIG
    );
    const ybStrategyMainnetSglDaiDeployment = getContract(
        hre,
        tag,
        DEPLOYMENT_NAMES.YB_SGL_MAINNET_DAI_STRATEGY,
    );

    return {
        tapToken,
        twTap,
        tob,
        oTap,
        tOlp,
        yieldbox,
        usdoDeployment,
        usdoOracleDeployment,
        usdcOracleDeployment,
        arbSglGlpDeployment,
        ybStrategyArbSglGlpDeployment,
        mainnetSglDaiDeployment,
        ybStrategyMainnetSglDaiDeployment,
    };
}

function getContract(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    contractName: string,
) {
    const contract = hre.SDK.db.findLocalDeployment(
        hre.SDK.eChainId,
        contractName,
        tag,
    )!;
    if (!contract) {
        throw new Error(
            `[-] ${contractName} not found on chain ${hre.network.name} tag ${tag}`,
        );
    }
    return contract;
}

function getGlobalDeployment(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    project: TAPIOCA_PROJECTS_NAME,
    chainId: string,
    contractName: string,
) {
    const contract = hre.SDK.db.findGlobalDeployment(
        project,
        chainId,
        contractName,
        tag,
    )!;
    if (!contract) {
        throw new Error(
            `[-] ${contractName} not found on project ${project} chain ${hre.network.name} tag ${tag}`,
        );
    }
    return contract;
}

async function registerAssetInYieldbox(
    hre: HardhatRuntimeEnvironment,
    sglDeployment: TContract,
    ybStrategy: TContract,
    yieldbox: IYieldBox,
    signer: SignerWithAddress,
) {
    const calls: TapiocaMulticall.CallStruct[] = [];

    // Check if SGL is registered
    const ybAsset = await yieldbox.ids(
        1,
        sglDeployment.address,
        ybStrategy.address,
        0,
    );
    // Check if SGL is registered in YieldBox
    if (ybAsset.toNumber() === 0) {
        console.log('[+] Depositing SGL_GLP to YieldBox');
        const balance = await (
            await hre.ethers.getContractAt('ERC20', sglDeployment.address)
        ).balanceOf(signer.address);
        calls.push({
            target: yieldbox.address,
            allowFailure: false,
            callData: yieldbox.interface.encodeFunctionData('depositAsset', [
                ybAsset,
                signer.address,
                signer.address,
                hre.ethers.utils.formatEther(balance),
                0,
            ]),
        });
        console.log('\t- Parameters', ybAsset, signer.address, balance, 0);
    }
    return calls;
}
