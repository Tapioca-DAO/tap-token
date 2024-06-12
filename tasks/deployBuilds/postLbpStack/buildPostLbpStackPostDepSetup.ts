import * as PERIPH_DEPLOY_CONFIG from '@tapioca-periph/config';
import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { TapiocaMulticall } from '@tapioca-sdk/typechain/tapioca-periphery';
import {
    AOTAP__factory,
    AirdropBroker__factory,
    TapToken__factory,
} from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadGlobalContract } from 'tapioca-sdk';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';
import { loadTapTokenLocalContract } from 'tasks/utils';

export const buildPostLbpStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<TapiocaMulticall.CallStruct[]> => {
    const calls: TapiocaMulticall.CallStruct[] = [];

    /**
     * Load contracts
     */
    const { adb, tapToken, usdcOracleDeployment, aoTap } = await loadContract(
        hre,
        tag,
    );

    /**
     * Broker claim for AOTAP
     */
    if ((await aoTap.broker()) !== adb.address) {
        console.log('[+] +Call queue: AOTAP broker claim');
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('aoTAPBrokerClaim'),
        });
    }

    /**
     * Set tapToken in ADB
     */
    if (
        (await adb.tapToken()).toLocaleLowerCase() !==
        tapToken.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set TapToken in AirdropBroker');
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setTapToken', [
                tapToken.address,
            ]),
        });
        console.log('\t- Parameters:', 'TapToken', tapToken.address);
    }

    /**
     * Set USDC as payment token in ADB
     */
    const usdcAddr = DEPLOY_CONFIG.MISC[hre.SDK.eChainId]!.USDC;
    if (
        (await adb.paymentTokens(usdcAddr)).oracle.toLocaleLowerCase() !==
        usdcOracleDeployment.address.toLocaleLowerCase()
    ) {
        console.log(
            '[+] +Call queue: set USDC as payment token in AirdropBroker',
        );
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setPaymentToken', [
                usdcAddr,
                usdcOracleDeployment.address,
                '0x',
            ]),
        });
        console.log(
            '\t- Parameters:',
            'USDC',
            usdcAddr,
            'USDC Oracle',
            usdcOracleDeployment.address,
            'Oracle Data',
            '0x',
        );
    }

    return calls;
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const usdcOracleDeployment = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.USDC_SEER_CL_ORACLE,
        tag,
    );

    const tapToken = TapToken__factory.connect(
        loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.TAP_TOKEN).address,
        hre.ethers.provider.getSigner(),
    );
    const adb = AirdropBroker__factory.connect(
        loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.AIRDROP_BROKER)
            .address,
        hre.ethers.provider.getSigner(),
    );
    const aoTap = AOTAP__factory.connect(
        loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.AOTAP).address,
        hre.ethers.provider.getSigner(),
    );

    return {
        tapToken,
        adb,
        usdcOracleDeployment,
        aoTap,
    };
}
