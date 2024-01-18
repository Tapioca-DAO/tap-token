import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapOFTSender__factory } from '../../../typechain';
import { IDependentOn } from '../../../gitsub_tapioca-sdk/src/ethers/hardhat/DeployerVM';

export const buildTapOFTSenderModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapOFTSender__factory['deploy']>,
): Promise<IDeployerVMAdd<TapOFTSender__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapOFTSender'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
