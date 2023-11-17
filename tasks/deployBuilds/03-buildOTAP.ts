import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { OTAP__factory } from '../../typechain';

export const buildOTAP = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
): Promise<IDeployerVMAdd<OTAP__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('OTAP'),
        deploymentName,
        args: [],
    };
};
