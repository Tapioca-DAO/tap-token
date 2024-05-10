import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Pearlmit__factory } from '@typechain/index';

// Temporary build function for Pearlmit.
// use tapioca-periph to deploy the real Pearlmit
export const temp__buildPearlmit = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<Pearlmit__factory['deploy']>,
): Promise<IDeployerVMAdd<Pearlmit__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('Pearlmit'),
        deploymentName,
        args,
    };
};
