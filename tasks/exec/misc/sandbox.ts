import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { DEPLOYMENT_NAMES } from '../../deploy/DEPLOY_CONFIG';

export const sandbox__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    const { tag } = _taskArgs;
    const VM = hre.SDK.DeployerVM.loadVM({ hre, tag });
    const tapiocaMulticallAddr = await VM.getMulticall();
    const signer = (await hre.ethers.getSigners())[0];

    const cluster = await hre.ethers.getContractAt(
        'TapiocaOptionBroker',
        loadLocalContract(
            hre,
            hre.SDK.eChainId,
            DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER,
            tag,
        ).address,
    );

    // set tapioca oracle
    await VM.executeMulticall([
        {
            target: cluster.address,
            allowFailure: false,
            callData: cluster.interface.encodeFunctionData('setTapOracle', [
                '0x3C8637521c16FAD5F498CA5d2808Db957d034744',
                '0x',
            ]),
        },
    ]);
};
