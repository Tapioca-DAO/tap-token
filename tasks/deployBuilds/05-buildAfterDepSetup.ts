import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TDeploymentVMContract } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';

export const buildAfterDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    deps: TDeploymentVMContract[],
): Promise<Multicall3.CallStruct[]> => {
    const calls: Multicall3.CallStruct[] = [];

    /**
     * Load addresses
     */
    const tapAddr = deps.find((e) => e.name === 'TapOFT')?.address;
    const twTapAddr = deps.find((e) => e.name === 'TwTAP')?.address;
    const tOBAddr = deps.find(
        (e) =>
            e.name === 'TapiocaOptionBroker' ||
            e.name === 'TapiocaOptionBrokerMock',
    )?.address;

    if (!tapAddr || !tOBAddr || !twTapAddr) {
        throw new Error('[-] One address not found');
    }

    /**
     * Load contracts
     */
    const tap = await hre.ethers.getContractAt('TapOFT', tapAddr);
    const tob = await hre.ethers.getContractAt('TapiocaOptionBroker', tOBAddr);

    /**
     * Set tOB as minter for TapOFT
     */

    if ((await tap.minter()) !== tOBAddr) {
        console.log('[+] Setting tOB as minter for TapOFT');
        await (await tap.setMinter(tOBAddr)).wait(1);
    }

    /**
     * Set tOB Broker role for tOB on oTAP
     */
    console.log('[+] +Call queue: oTAP broker claim');
    calls.push({
        target: tOBAddr,
        allowFailure: false,
        callData: tob.interface.encodeFunctionData('oTAPBrokerClaim'),
    });

    /**
     * Set twTAP in TapOFT
     */
    console.log('[+] +Call queue: set twTAP in TapOFT');
    calls.push({
        target: tapAddr,
        allowFailure: false,
        callData: tap.interface.encodeFunctionData('setTwTap', [twTapAddr]),
    });
    return calls;
};
