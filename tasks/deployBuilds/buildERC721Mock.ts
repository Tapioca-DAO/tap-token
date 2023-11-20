import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { ERC721Mock__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';

export const buildERC721Mock = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<ERC721Mock__factory['deploy']>,
): Promise<IDeployerVMAdd<ERC721Mock__factory>> => {
    return {
        contract: new ERC721Mock__factory((await hre.ethers.getSigners())[0]),
        deploymentName,
        args,
    };
};
