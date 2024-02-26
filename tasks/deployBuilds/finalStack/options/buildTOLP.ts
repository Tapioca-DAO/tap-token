import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapiocaOptionLiquidityProvision__factory } from '@typechain/index';

export const buildTolp = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapiocaOptionLiquidityProvision__factory['deploy']>,
): Promise<IDeployerVMAdd<TapiocaOptionLiquidityProvision__factory>> => ({
    contract: await hre.ethers.getContractFactory(
        'TapiocaOptionLiquidityProvision',
    ),
    deploymentName,
    args,
});
