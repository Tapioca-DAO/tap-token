import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { AOTAP__factory } from '@typechain/index';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';

export const buildAOTAP = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<AOTAP__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<AOTAP__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('AOTAP'),
        deploymentName,
        args,
        dependsOn,
    };
};
