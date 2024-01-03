import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { Vesting__factory } from '../../typechain';

export const buildVesting = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<Vesting__factory['deploy']>,
): Promise<IDeployerVMAdd<Vesting__factory>> => {
    return {
        contract: (await hre.ethers.getContractFactory(
            'Vesting',
        )) as Vesting__factory,
        deploymentName,
        args,
    };
};
