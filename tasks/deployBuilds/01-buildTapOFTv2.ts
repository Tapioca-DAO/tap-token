import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapOFTV2__factory } from '../../typechain';
import { IDependentOn } from '../../gitsub_tapioca-sdk/src/ethers/hardhat/DeployerVM';

export const buildTapOFTv2 = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapOFTV2__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TapOFTV2__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapOFTV2'),
        deploymentName,
        args,
        dependsOn,
    };
};
