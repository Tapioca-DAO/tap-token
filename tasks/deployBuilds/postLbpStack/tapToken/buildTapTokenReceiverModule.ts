import { TapTokenReceiver__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTapTokenReceiverModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapTokenReceiver__factory['deploy']>,
): Promise<IDeployerVMAdd<TapTokenReceiver__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapTokenReceiver'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
