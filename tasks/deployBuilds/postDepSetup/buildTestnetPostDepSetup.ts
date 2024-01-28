import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TDeploymentVMContract } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';

export const buildTestnetPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    deps: TDeploymentVMContract[],
): Promise<Multicall3.CallStruct[]> => {
    const calls: Multicall3.CallStruct[] = [];

    /**
     * Load addresses
     */
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
    const wethmOracleAddr = deps.find(
        (e) => e.name === 'WETHMOracleMock',
    )?.address;
    const usdcmOracleAddr = deps.find(
        (e) => e.name === 'USDCMOracleMock',
    )?.address;

    if (
        !tapAddr ||
        !tOBAddr ||
        !tOLPAddr ||
        !tapOFTOracleMockAddr ||
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

    const oracleMock = await hre.ethers.getContractAt(
        'OracleMock',
        wethmOracleAddr,
    );

    /**
     * Setting oracle rates
     */
    console.log('[+] +Call queue: oracle rates');
    calls.push({
        target: wethmOracleAddr,
        callData: oracleMock.interface.encodeFunctionData('setRate', [
            hre.ethers.BigNumber.from((1480e18).toString()).toString(),
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

    return calls;
};
