import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapOFTv2Helper__factory } from '../../../typechain';
import { IDependentOn } from '../../../gitsub_tapioca-sdk/src/ethers/hardhat/DeployerVM';

export const buildTapOFTHelper = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapOFTv2Helper__factory['deploy']>,
): Promise<IDeployerVMAdd<TapOFTv2Helper__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapOFTv2Helper'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
