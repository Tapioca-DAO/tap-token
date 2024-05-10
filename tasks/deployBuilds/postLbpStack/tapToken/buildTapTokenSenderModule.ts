import { TapTokenSender__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTapTokenSenderModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapTokenSender__factory['deploy']>,
): Promise<IDeployerVMAdd<TapTokenSender__factory>> => {
    return {
        contract: new TapTokenSender__factory(hre.ethers.provider.getSigner()),
        deploymentName,
        args,
        dependsOn: [],
    };
};
