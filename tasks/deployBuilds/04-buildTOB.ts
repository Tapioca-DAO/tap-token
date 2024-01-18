import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapiocaOptionBroker__factory } from '../../typechain';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';

export const buildTOB = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapiocaOptionBroker__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TapiocaOptionBroker__factory>> => {
    return {
        contract: (await hre.ethers.getContractFactory(
            deploymentName,
        )) as TapiocaOptionBroker__factory,
        deploymentName,
        args,
        dependsOn,
    };
};
