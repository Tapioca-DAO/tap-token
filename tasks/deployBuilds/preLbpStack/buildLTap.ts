import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { LTap__factory } from '@typechain/index';

export const buildLTap = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<LTap__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<LTap__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('LTap'),
        deploymentName,
        args,
        dependsOn,
    };
};
