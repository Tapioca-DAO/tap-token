import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TwTAP__factory } from '@typechain/index';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';

export const buildTwTap = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TwTAP__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TwTAP__factory>> => {
    return {
        contract: new TwTAP__factory(hre.ethers.provider.getSigner()),
        deploymentName,
        args,
        dependsOn,
    };
};
