import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { AirdropBroker__factory } from '../../typechain';

export const buildADB = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<AirdropBroker__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<AirdropBroker__factory>> => {
    return {
        contract: (await hre.ethers.getContractFactory(
            deploymentName,
        )) as AirdropBroker__factory,
        deploymentName,
        args,
        dependsOn,
    };
};
