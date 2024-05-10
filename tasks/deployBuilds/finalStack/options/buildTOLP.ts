import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapiocaOptionLiquidityProvision__factory } from '@typechain/index';

export const buildTolp = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapiocaOptionLiquidityProvision__factory['deploy']>,
): Promise<IDeployerVMAdd<TapiocaOptionLiquidityProvision__factory>> => ({
    contract: new TapiocaOptionLiquidityProvision__factory(
        hre.ethers.provider.getSigner(),
    ),
    deploymentName,
    args,
});
