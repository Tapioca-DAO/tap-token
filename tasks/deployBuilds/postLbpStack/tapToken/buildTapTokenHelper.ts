import { TapTokenHelper__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTapTokenHelper = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapTokenHelper__factory['deploy']>,
): Promise<IDeployerVMAdd<TapTokenHelper__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapTokenHelper'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
