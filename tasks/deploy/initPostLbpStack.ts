import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadVM } from '../utils';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';

export const initPostLbpStack__task = async (
    taskArgs: { tag?: string; load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = taskArgs.tag ?? 'default';
    const VM = await loadVM(hre, tag);

    console.log('[+] Init post LBP stack');
    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        getContract(hre, tag, DEPLOYMENT_NAMES.AIRDROP_BROKER).address,
    );
    console.log('[+] AirdropBroker found on', adb.address);
    console.log('[+] New epoch on ADB');
    await VM.executeMulticall([
        {
            target: adb.address,
            callData: adb.interface.encodeFunctionData('newEpoch'),
            allowFailure: false,
        },
    ]);
    console.log('[+] ADB new epoch executed');
};

function getContract(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    contractName: string,
) {
    const contract = hre.SDK.db.findLocalDeployment(
        String(hre.network.config.chainId),
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
