import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TDeploymentVMContract } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { Multicall3 } from '../../typechain';

export const buildTestnetAfterDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    deps: TDeploymentVMContract[],
): Promise<Multicall3.Call3Struct[]> => {
    const calls: Multicall3.Call3Struct[] = [];

    /**
     * Load addresses
     */
    const yieldBoxAddr = deps.find((e) => e.name === 'YieldBoxMock')?.address;
    const tapAddr = deps.find((e) => e.name === 'TapOFT')?.address;
    const tOBAddr = deps.find(
        (e) =>
            e.name === 'TapiocaOptionBroker' ||
            e.name === 'TapiocaOptionBrokerMock',
    )?.address;
    const tOLPAddr = deps.find(
        (e) => e.name === 'TapiocaOptionLiquidityProvision',
    )?.address;
    const tapOFTOracleMockAddr = deps.find(
        (e) => e.name === 'TapOFTOracleMock',
    )?.address;
    const sglTokenMock1Addr = deps.find(
        (e) => e.name === 'sglTokenMock1',
    )?.address;
    const sglTokenMock2Addr = deps.find(
        (e) => e.name === 'sglTokenMock2',
    )?.address;
    const ybStrat1Addr = deps.find(
        (e) => e.name === 'YieldBoxVaultStratSGlTokenMock1',
    )?.address;
    const ybStrat2Addr = deps.find(
        (e) => e.name === 'YieldBoxVaultStratSGlTokenMock2',
    )?.address;
    const wethmOracleAddr = deps.find(
        (e) => e.name === 'WETHMOracleMock',
    )?.address;
    const usdcmOracleAddr = deps.find(
        (e) => e.name === 'USDCMOracleMock',
    )?.address;

    if (
        !yieldBoxAddr ||
        !tapAddr ||
        !tOBAddr ||
        !tOLPAddr ||
        !tapOFTOracleMockAddr ||
        !sglTokenMock1Addr ||
        !sglTokenMock2Addr ||
        !ybStrat1Addr ||
        !ybStrat2Addr ||
        !wethmOracleAddr ||
        !usdcmOracleAddr
    ) {
        throw new Error('[-] One address not found');
    }

    /**
     * Load contracts
     */
    const tob = await hre.ethers.getContractAt('TapiocaOptionBroker', tOBAddr);
    const tOLP = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        tOLPAddr,
    );
    const yieldBoxMock = await hre.ethers.getContractAt(
        'YieldBox',
        yieldBoxAddr,
    );
    const oracleMock = await hre.ethers.getContractAt(
        'OracleMock',
        wethmOracleAddr,
    );

    /**
     * Register YieldBox Assets
     */
    console.log('[+] +Call queue: Register YieldBox Asset');
    calls.push({
        target: yieldBoxAddr,
        callData: yieldBoxMock.interface.encodeFunctionData('registerAsset', [
            1,
            sglTokenMock1Addr,
            ybStrat1Addr,
            0,
        ]),
        allowFailure: false,
    });
    calls.push({
        target: yieldBoxAddr,
        callData: yieldBoxMock.interface.encodeFunctionData('registerAsset', [
            1,
            sglTokenMock2Addr,
            ybStrat2Addr,
            0,
        ]),
        allowFailure: false,
    });

    /**
     * Register Singularity in tOLP
     */
    if ((await tOLP.sglAssetIDToAddress(1)) !== sglTokenMock1Addr) {
        console.log('[+] Setting tOLP Singularity 1');
        await (await tOLP.registerSingularity(sglTokenMock1Addr, 1, 0)).wait(1);
    }
    if ((await tOLP.sglAssetIDToAddress(2)) !== sglTokenMock2Addr) {
        console.log('[+] Setting tOLP Singularity 2');
        await (await tOLP.registerSingularity(sglTokenMock2Addr, 2, 0)).wait(1);
    }

    /**
     * Setting oracle rates
     */
    console.log('[+] +Call queue: oracle rates');
    calls.push({
        target: wethmOracleAddr,
        callData: oracleMock.interface.encodeFunctionData('setRate', [
            hre.ethers.BigNumber.from(1480e8).toString(),
        ]),
        allowFailure: false,
    });
    calls.push({
        target: usdcmOracleAddr,
        callData: oracleMock.interface.encodeFunctionData('setRate', [
            hre.ethers.BigNumber.from(1e8).toString(),
        ]),
        allowFailure: false,
    });

    /**
     * Set tOB payment tokens
     */
    if (
        (await tob.paymentTokens(sglTokenMock1Addr)).oracle !== wethmOracleAddr
    ) {
        console.log('[+] Setting tOB payment token 1');
        await (
            await tob.setPaymentToken(
                sglTokenMock1Addr,
                wethmOracleAddr,
                '0x00',
            )
        ).wait(1);
    }
    if (
        (await tob.paymentTokens(sglTokenMock2Addr)).oracle !== usdcmOracleAddr
    ) {
        console.log('[+] Setting tOB payment token 2');
        await (
            await tob.setPaymentToken(
                sglTokenMock2Addr,
                usdcmOracleAddr,
                '0x00',
            )
        ).wait(1);
    }
    return calls;
};
