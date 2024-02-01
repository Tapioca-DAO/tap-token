import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadVM } from '../utils';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';

export const initFinalStack__task = async (
    taskArgs: { tag?: string; load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = taskArgs.tag ?? 'default';

    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        Number(hre.network.config.chainId),
    )!;

    const VM = await loadVM(hre, tag);

    console.log('[+] Init Final stack');

    const tob = await hre.ethers.getContractAt(
        'TapiocaOptionBroker',
        getContract(hre, tag, DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER).address,
    );
    console.log('[+] TapiocaOptionBroker found on', tob.address);
    console.log('[+] New epoch on TOB');
    await VM.executeMulticall([
        {
            target: tob.address,
            callData: tob.interface.encodeFunctionData('newEpoch'),
            allowFailure: false,
        },
    ]);
    console.log('[+] TOB new epoch executed');

    const twTap = await hre.ethers.getContractAt(
        'TwTAP',
        getContract(hre, tag, DEPLOYMENT_NAMES.TWTAP).address,
    );
    console.log('[+] TapiocaOptionBroker found on', twTap.address);
    console.log('[+] New epoch on TwTap');
    await VM.executeMulticall([
        {
            target: twTap.address,
            callData: twTap.interface.encodeFunctionData('advanceWeek', [1]),
            allowFailure: false,
        },
    ]);
    console.log('[+] TwTap new epoch executed');
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
