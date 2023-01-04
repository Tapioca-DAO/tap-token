import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import { TContract } from 'tapioca-sdk/dist/shared';
import { getDeployments } from './getDeployments';

export const getTapContract = async (hre: HardhatRuntimeEnvironment) => {
    let deployments: TContract[] = [];
    try {
        deployments = await getDeployments(hre, true);
    } catch (e) {
        deployments = await getDeployments(hre);
    }

    const tapOft = _.find(deployments, { name: 'tapOFT' });
    if (!tapOft) {
        throw new Error('[-] TapOFT not found');
    }

    const tapOFTContract = await hre.ethers.getContractAt('TapOFT', tapOft.address);
    return { tapOFTContract };
};
