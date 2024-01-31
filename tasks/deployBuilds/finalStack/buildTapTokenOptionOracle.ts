import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TapOptionOracle__factory } from '@tapioca-sdk/typechain/tapioca-periphery';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTapTokenOptionOracle = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapOptionOracle__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TapOptionOracle__factory>> => {
    const signer = (await hre.ethers.getSigners())[0];
    return {
        contract: new TapOptionOracle__factory(signer),
        deploymentName,
        args,
        dependsOn,
    };
};
