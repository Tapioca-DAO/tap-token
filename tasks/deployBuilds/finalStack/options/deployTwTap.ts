import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TwTAP__factory } from '@typechain/index';

export const buildTwTap = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TwTAP__factory['deploy']>,
): Promise<IDeployerVMAdd<TwTAP__factory>> => {
    return {
        contract: (await hre.ethers.getContractFactory(
            'TwTAP',
        )) as TwTAP__factory,
        deploymentName,
        args,
        dependsOn: [],
    };
};
