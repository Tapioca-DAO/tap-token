import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TContract, TLocalDeployment } from 'tapioca-sdk/dist/shared';
import { EChainID } from '@tapioca-sdk/api/config';
import { loadVM } from '../utils';
import { Multicall3 } from '@tapioca-sdk/typechain/tapioca-periphery';
import { TapOFTV2__factory } from '@typechain/index';

// hh deployTapOFT -network goerli
export const setOFTPeers__task = async (
    taskArgs: {
        target: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const VM = await loadVM(hre, tag);
    const multicall: Multicall3 = await VM.getMulticall();

    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        Number(hre.network.config.chainId),
    )!;

    // Load target contract locally
    const localDeployments = hre.SDK.db.readDeployment('local', {
        tag,
    }) as TLocalDeployment;
    const localContract = localDeployments[chainInfo.chainId]?.find(
        (e) => e.name === taskArgs.target,
    );
    if (!localContract) {
        throw new Error(`[-] Contract ${taskArgs.target} not found`);
    }

    // Load contracts to link
    const links = await getLinkedContract(hre, tag, localContract);

    // Transfer Ownership at the beginning of the calls
    const tapOFTv2 = await hre.ethers.getContractAt(
        'TapOFTV2',
        localContract.address,
    );
    await (await tapOFTv2.transferOwnership(multicall.address)).wait(3);

    // Prepare calls
    const calls: IMulticall3.Call3Struct[] = [];
    for (const link of links) {
        calls.push({
            target: localContract.address,
            callData: TapOFTV2__factory.createInterface().encodeFunctionData(
                'setPeer',
                [
                    link.lzChainId,
                    hre.ethers.utils.defaultAbiCoder.encode(
                        ['address'],
                        [link.contract.address],
                    ),
                ],
            ),
            allowFailure: false,
        });
    }

    // Transfer Ownership at the end of the calls
    calls.push({
        target: localContract.address,
        callData: TapOFTV2__factory.createInterface().encodeFunctionData(
            'transferOwnership',
            [signer.address],
        ),
        allowFailure: false,
    });

    // Execute
    const tx = await multicall.multicall(calls);
    console.log('[+] Tx sent: ', tx.hash);
    await tx.wait(3);
    console.log('[+] Tx mined!');
};

async function getLinkedContract(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    contractToConf: TContract,
    chainId?: string,
) {
    // TODO - Could be a util
    let targets: { lzChainId: string; contract: TContract }[] = [];
    const localDeployments = hre.SDK.db.readDeployment('local', {
        tag,
    }) as TLocalDeployment;
    const localChainIds = Object.keys(localDeployments).filter(
        (e) => e !== String(hre.network.config.chainId),
    );

    // For each chain, get the matching contract
    for (const chainId of localChainIds) {
        const linked = localDeployments[chainId].find(
            (e) => e.name === contractToConf.name,
        );
        if (linked) {
            targets.push({
                lzChainId:
                    hre.SDK.config.NETWORK_MAPPING_CHAIN_TO_LZ[
                        chainId as EChainID
                    ],
                contract: linked,
            });
        }
    }

    if (chainId) {
        targets = targets.filter((e) => e.lzChainId == chainId);
    }

    const supportedChain = hre.SDK.utils.getSupportedChains();
    const { isOk } = await inquirer.prompt({
        type: 'confirm',
        message: `Do you want to configure ${contractToConf.name} on ${targets
            .map(
                (e) =>
                    supportedChain.find((c) => c.lzChainId === e.lzChainId)
                        ?.name,
            )
            .join(', ')}?`,
        name: 'isOk',
    });

    if (!isOk) {
        throw new Error('[-] Aborted');
    }

    return targets;
}
