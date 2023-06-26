import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { constants } from '../../scripts/deployment.utils';
import { TapOFT__factory } from '../../typechain';

export const buildTapOFT = async (
    hre: HardhatRuntimeEnvironment,
    args: Parameters<TapOFT__factory['deploy']>,
): Promise<IDeployerVMAdd<TapOFT__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapOFT'),
        deploymentName: 'TapOFT',
        args,
    };
};
