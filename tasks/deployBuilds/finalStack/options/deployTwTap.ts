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
        contract: (await hre.ethers.getContractFactory(
            'LTap',
        )) as TwTAP__factory,
        deploymentName,
        args,
        dependsOn,
    };
};
