import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TDeploymentVMContract } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';

export const buildStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    deps: TDeploymentVMContract[],
): Promise<Multicall3.CallStruct[]> => {
    const calls: Multicall3.CallStruct[] = [];

    /**
     * Load addresses
     */
    const tapAddr = deps.find((e) => e.name === 'TapToken')?.address;
    const twTapAddr = deps.find((e) => e.name === 'TwTAP')?.address;
    const tOBAddr = deps.find(
        (e) =>
            e.name === 'TapiocaOptionBroker' ||
            e.name === 'TapiocaOptionBrokerMock',
    )?.address;
    const oTapAddr = deps.find((e) => e.name === 'OTAP')?.address;

    if (!tapAddr) {
        throw new Error('[-] TAP not found');
    }

    if (!tOBAddr) {
        throw new Error('[-] tOB not found');
    }

    if (!twTapAddr) {
        throw new Error('[-] twTap not found');
    }
    if (!oTapAddr) {
        throw new Error('[-] oTap not found');
    }

    /**
     * Load contracts
     */
    const tap = await hre.ethers.getContractAt('TapToken', tapAddr);
    const tob = await hre.ethers.getContractAt('TapiocaOptionBroker', tOBAddr);
    const oTap = await hre.ethers.getContractAt('OTAP', oTapAddr);

    /**
     * Set tOB as minter for TapOFT
     */

    if (
        (await tap.minter()).toLocaleLowerCase() !== tOBAddr.toLocaleLowerCase()
    ) {
        console.log('[+] Setting tOB as minter for TapToken');
        await (await tap.setMinter(tOBAddr)).wait(1);
    }

    /**
     * Set tOB Broker role for tOB on oTAP
     */
    if (
        (await oTap.broker()).toLocaleLowerCase() !==
        tOBAddr.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: oTAP broker claim');
        calls.push({
            target: tOBAddr,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('oTAPBrokerClaim'),
        });
    }

    /**
     * Set twTAP in TapOFT
     */
    if (
        (await tap.twTap()).toLocaleLowerCase() !==
        twTapAddr.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set twTAP in TapToken');
        calls.push({
            target: tapAddr,
            allowFailure: false,
            callData: tap.interface.encodeFunctionData('setTwTAP', [twTapAddr]),
        });
    }
    return calls;
};
