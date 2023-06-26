import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TwTAP__factory } from '../../typechain';

export const buildTwTap = async (
    hre: HardhatRuntimeEnvironment,
    args: Parameters<TwTAP__factory['deploy']>,
): Promise<IDeployerVMAdd<TwTAP__factory>> => {
    const deploymentName = 'TwTAP';
    return {
        contract: (await hre.ethers.getContractFactory(
            deploymentName,
        )) as TwTAP__factory,
        deploymentName,
        args,
        dependsOn: [{ argPosition: 0, deploymentName: 'TapOFT' }],
    };
};
