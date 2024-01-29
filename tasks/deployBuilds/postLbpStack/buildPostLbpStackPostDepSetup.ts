import { EChainID } from '@tapioca-sdk/api/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import { DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';

export const buildLbpStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<Multicall3.CallStruct[]> => {
    const calls: Multicall3.CallStruct[] = [];

    /**
     * Load contracts
     */
    const { adb, tapToken, tapOracleDeployment, usdcOracleDeployment } =
        await loadContract(hre, tag);

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
     * Set Tap oracle in ADB
     */
    if (
        (await adb.tapToken()).toLocaleLowerCase() !==
        tapOracleDeployment.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set TapToken in AirdropBroker');
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setTapOracle', [
                tapOracleDeployment.address,
                '0x00',
            ]),
        });
    }

    /**
     * Set USDC as payment token in ADB
     */
    const usdcAddr = DEPLOY_CONFIG[EChainID.ARBITRUM].ADB.USDC_PAYMENT_TOKEN;
    if (
        (await adb.paymentTokens(usdcAddr)).oracle.toLocaleLowerCase() !==
        usdcAddr.toLocaleLowerCase()
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
                '0x00',
            ]),
        });
        console.log(
            '\t- Parameters:',
            'USDC',
            usdcAddr,
            'USDC Oracle',
            usdcOracleDeployment.address,
            'Oracle Data',
            '0x00',
        );
    }

    return calls;
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const validateAddress = (addr: any, contractName: string) => {
        if (!addr) {
            throw new Error(
                `[-] ${contractName} not found on chain ${hre.network.name} tag ${tag}`,
            );
        }
    };

    const tapTokenDeployment = hre.SDK.db.findLocalDeployment(
        String(hre.network.config.chainId),
        'TapToken',
        tag,
    )!;
    validateAddress(tapTokenDeployment, 'TapToken');

    const adbDeployment = hre.SDK.db.findLocalDeployment(
        String(hre.network.config.chainId),
        'AirdropBroker',
        tag,
    )!;
    validateAddress(adbDeployment, 'AirdropBroker');

    const aoTapDeployment = hre.SDK.db.findLocalDeployment(
        String(hre.network.config.chainId),
        'AoTap',
        tag,
    )!;
    validateAddress(adbDeployment, 'AirdropBroker');

    const tapOracleDeployment = hre.SDK.db.findLocalDeployment(
        String(hre.network.config.chainId),
        'TapOracle',
        tag,
    )!;
    validateAddress(adbDeployment, 'TapOracle');

    const usdcOracleDeployment = hre.SDK.db.findLocalDeployment(
        String(hre.network.config.chainId),
        'UsdcOracle',
        tag,
    )!;
    validateAddress(adbDeployment, 'UsdcOracle');

    const tapToken = await hre.ethers.getContractAt(
        'TapToken',
        tapTokenDeployment.address,
    );
    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        adbDeployment.address,
    );

    return {
        tapToken,
        adb,
        tapOracleDeployment,
        usdcOracleDeployment,
        aoTapDeployment,
    };
}
