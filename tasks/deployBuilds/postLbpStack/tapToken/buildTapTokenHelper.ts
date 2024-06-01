import { TapTokenHelper__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';

export const buildTapTokenHelper = async (
    hre: HardhatRuntimeEnvironment,
): Promise<IDeployerVMAdd<TapTokenHelper__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TapTokenHelper'),
        deploymentName: DEPLOYMENT_NAMES.TAP_TOKEN_HELPER,
        args: [],
    };
};
