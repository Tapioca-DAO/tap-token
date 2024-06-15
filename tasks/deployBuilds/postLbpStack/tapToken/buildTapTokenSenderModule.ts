import { TapTokenSender__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTapTokenSenderModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapTokenSender__factory['deploy']>,
): Promise<IDeployerVMAdd<TapTokenSender__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapTokenSender'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
