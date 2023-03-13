import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { OTAP__factory } from '../../typechain';
import { IDeployerVMAdd } from '../deployerVM';

export const buildOTAP = async (
    hre: HardhatRuntimeEnvironment,
): Promise<IDeployerVMAdd<OTAP__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('OTAP'),
        deploymentName: 'OTAP',
        args: [],
    };
};
