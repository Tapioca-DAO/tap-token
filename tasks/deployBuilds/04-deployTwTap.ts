import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TwTAP__factory } from '../../typechain';
import { IDependentOn } from '../../gitsub_tapioca-sdk/src/ethers/hardhat/DeployerVM';

export const buildTwTap = async (
    hre: HardhatRuntimeEnvironment,
    args: Parameters<TwTAP__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TwTAP__factory>> => {
    const deploymentName = 'TwTAP';
    return {
        contract: (await hre.ethers.getContractFactory(
            'TwTAP',
        )) as TwTAP__factory,
        deploymentName,
        args,
        dependsOn,
    };
};
