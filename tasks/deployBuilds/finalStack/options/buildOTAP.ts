import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { OTAP__factory } from '@typechain/index';

export const buildOTAP = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: IDeployerVMAdd<OTAP__factory>['args'],
): Promise<IDeployerVMAdd<OTAP__factory>> => {
    return {
        contract: new OTAP__factory(hre.ethers.provider.getSigner()),
        deploymentName,
        args,
    };
};
