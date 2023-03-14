import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { constants } from '../../scripts/deployment.utils';
import { TapOFT__factory } from '../../typechain';
import { IDeployerVMAdd } from '../deployerVM';

export const buildTapOFT = async (
    hre: HardhatRuntimeEnvironment,
    signer: string,
): Promise<IDeployerVMAdd<TapOFT__factory>> => {
    const chainId = await hre.getChainId();

    const lzEndpoint = constants[chainId as '5'].address as string;
    const contributorAddress = constants.teamAddress;
    const investorAddress = constants.advisorAddress;
    const lbpAddress = constants.daoAddress;
    const airdropAddress = constants.seedAddress;
    const daoAddress = constants.daoAddress;
    const governanceChainId = constants.governanceChainId.toString();

    return {
        contract: await hre.ethers.getContractFactory('TapOFT'),
        deploymentName: 'TapOFT',
        args: [
            lzEndpoint,
            contributorAddress,
            investorAddress,
            lbpAddress,
            daoAddress,
            airdropAddress,
            governanceChainId,
            signer,
        ],
    };
};
