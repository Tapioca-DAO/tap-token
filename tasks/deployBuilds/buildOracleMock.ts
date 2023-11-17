import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { OracleMock__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';

export const buildOracleMock = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<OracleMock__factory['deploy']>,
): Promise<IDeployerVMAdd<OracleMock__factory>> => {
    return {
        contract: new OracleMock__factory((await hre.ethers.getSigners())[0]),
        deploymentName,
        args,
    };
};
