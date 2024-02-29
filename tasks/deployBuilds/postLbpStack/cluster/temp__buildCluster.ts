import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Cluster__factory } from '@typechain/index';

// Temporary build function for Cluster.
// use tapioca-periph to deploy the real Cluster
export const temp__buildCluster = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<Cluster__factory['deploy']>,
): Promise<IDeployerVMAdd<Cluster__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('Cluster'),
        deploymentName,
        args,
    };
};
