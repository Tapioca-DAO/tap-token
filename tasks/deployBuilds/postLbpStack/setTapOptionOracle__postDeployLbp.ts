import * as PERIPH_DEPLOY_CONFIG from '@tapioca-periph/config';
import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { TapiocaMulticall } from '@tapioca-sdk/typechain/tapioca-periphery';
import { AirdropBroker__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadGlobalContract } from 'tapioca-sdk';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';
import { loadTapTokenLocalContract } from 'tasks/utils';

export const setTapOptionOracle__postDeployLbp = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<TapiocaMulticall.CallStruct[]> => {
    const calls: TapiocaMulticall.CallStruct[] = [];

    /**
     * Load contracts
     */
    const { adb, tapAdbOptionOracle, usdcOracleDeployment } =
        await loadContract(hre, tag);

    /**
     * Set Tap Option oracle in ADB
     */
    if (
        (await adb.tapToken()).toLocaleLowerCase() !==
        tapAdbOptionOracle.address.toLocaleLowerCase()
    ) {
        console.log(
            '[+] +Call queue: set TapToken Option Oracle in AirdropBroker',
        );
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setTapOracle', [
                tapAdbOptionOracle.address,
                '0x',
            ]),
        });
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
    const tapAdbOptionOracle = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.eChainId,
        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.TAP_ORACLE,
        tag,
    );

    const adb = AirdropBroker__factory.connect(
        loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.AIRDROP_BROKER)
            .address,
        hre.ethers.provider.getSigner(),
    );

    return {
        adb,
        tapAdbOptionOracle,
        usdcOracleDeployment,
    };
}
