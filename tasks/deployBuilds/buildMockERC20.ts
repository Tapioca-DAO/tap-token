import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { ERC20Mock__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';

export const buildERC20Mock = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<ERC20Mock__factory['deploy']>,
): Promise<IDeployerVMAdd<ERC20Mock__factory>> => {
    return {
        contract: new ERC20Mock__factory((await hre.ethers.getSigners())[0]),
        deploymentName,
        args,
    };
};
