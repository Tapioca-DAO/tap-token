import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TDeploymentVMContract } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { Multicall3 } from '../../typechain';

export const buildAfterDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    deps: TDeploymentVMContract[],
): Promise<Multicall3.Call3Struct[]> => {
    const calls: Multicall3.Call3Struct[] = [];

    /**
     * Load addresses
     */
    const tapAddr = deps.find((e) => e.name === 'TapOFT')?.address;
    const tOBAddr = deps.find(
        (e) =>
            e.name === 'TapiocaOptionBroker' ||
            e.name === 'TapiocaOptionBrokerMock',
    )?.address;
    const tapOFTOracleMockAddr = deps.find(
        (e) => e.name === 'TapOFTOracleMock',
    )?.address;

    if (!tapAddr || !tOBAddr || !tapOFTOracleMockAddr) {
        throw new Error('[-] One address not found');
    }

    /**
     * Load contracts
     */
    const tap = await hre.ethers.getContractAt('TapOFT', tapAddr);
    const tob = await hre.ethers.getContractAt('TapiocaOptionBroker', tOBAddr);
    const TapOFTOracleMock = await hre.ethers.getContractAt(
        'OracleMock',
        tapOFTOracleMockAddr,
    );

    /**
     * Set tOB as minter for TapOFT
     */

    if ((await tap.minter()) !== tOBAddr) {
        console.log('[+] Setting tOB as minter for TapOFT');
        await (await tap.setMinter(tOBAddr)).wait(1);
    }

    console.log('[+] +Call queue: oTAP broker claim');
    calls.push({
        target: tOBAddr,
        allowFailure: false,
        callData: tob.interface.encodeFunctionData('oTAPBrokerClaim'),
    });

    /**
     * Set tOB TapOFT oracle
     */

    if ((await tob.tapOracle()) !== tapOFTOracleMockAddr) {
        console.log('[+] Setting tOB TapOFT oracle');
        await (await tob.setTapOracle(tapOFTOracleMockAddr, '0x00')).wait(1);
    }

    /**
     * Set TapOFT oracle rate
     */
    console.log('[+] +Call queue: TapOFT oracle rate');
    calls.push({
        target: tapOFTOracleMockAddr,
        callData: TapOFTOracleMock.interface.encodeFunctionData('setRate', [
            12e7,
        ]),
        allowFailure: false,
    });

    return calls;
};
