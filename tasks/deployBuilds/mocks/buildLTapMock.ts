import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { LTapMock__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildLTapMock = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<LTapMock__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<LTapMock__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('LTapMock'),
        deploymentName,
        args,
        dependsOn,
    };
};
