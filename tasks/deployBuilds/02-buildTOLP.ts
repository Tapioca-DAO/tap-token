import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { TapiocaOptionLiquidityProvision__factory } from '../../typechain';

export const buildTOLP = async (
    hre: HardhatRuntimeEnvironment,
    signerAddr: string,
    yieldBoxAddr: string,
): Promise<IDeployerVMAdd<TapiocaOptionLiquidityProvision__factory>> => ({
    contract: await hre.ethers.getContractFactory(
        'TapiocaOptionLiquidityProvision',
    ),
    deploymentName: 'TapiocaOptionLiquidityProvision',
    args: [yieldBoxAddr, signerAddr],
});
