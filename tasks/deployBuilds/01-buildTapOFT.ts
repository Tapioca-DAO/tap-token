import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapOFT__factory } from '../../typechain';

export const buildTapOFT = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapOFT__factory['deploy']>,
): Promise<IDeployerVMAdd<TapOFT__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapOFT'),
        deploymentName,
        args,
    };
};
