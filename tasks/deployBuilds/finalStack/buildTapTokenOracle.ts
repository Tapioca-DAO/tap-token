import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { Seer__factory } from '@tapioca-sdk/typechain/tapioca-periphery';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTapTokenOracle = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<Seer__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<Seer__factory>> => {
    const signer = (await hre.ethers.getSigners())[0];
    return {
        contract: new Seer__factory(signer),
        deploymentName,
        args,
        dependsOn,
    };
};
