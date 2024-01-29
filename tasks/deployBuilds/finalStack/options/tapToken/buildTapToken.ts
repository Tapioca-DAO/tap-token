import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TapToken__factory } from '@typechain/index';

export const buildTapToken = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapToken__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TapToken__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapToken'),
        deploymentName,
        args,
        dependsOn,
    };
};
