import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { ERC20WithoutStrategy__factory } from '@tapioca-sdk/typechain/YieldBox';

export const buildEmptyYbStrategy = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<ERC20WithoutStrategy__factory['deploy']>,
): Promise<IDeployerVMAdd<ERC20WithoutStrategy__factory>> => {
    const signer = (await hre.ethers.getSigners())[0];
    return {
        contract: new ERC20WithoutStrategy__factory(signer),
        deploymentName,
        args,
        dependsOn: [],
    };
};
