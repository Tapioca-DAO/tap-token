import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapOFTReceiver__factory } from '../../../typechain';
import { IDependentOn } from '../@tapioca-sdk/ethers/hardhat/DeployerVM';

export const buildTapOFTReceiverModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapOFTReceiver__factory['deploy']>,
): Promise<IDeployerVMAdd<TapOFTReceiver__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapOFTReceiver'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
