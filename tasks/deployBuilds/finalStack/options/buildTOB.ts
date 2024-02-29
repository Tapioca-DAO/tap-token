import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TapiocaOptionBroker__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTOB = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapiocaOptionBroker__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TapiocaOptionBroker__factory>> => {
    return {
        contract: new TapiocaOptionBroker__factory(
            hre.ethers.provider.getSigner(),
        ),
        deploymentName,
        args,
        dependsOn,
        runStaticSimulation: false, // We don't want to run the simulation for this contract because of the constructor check
    };
};
