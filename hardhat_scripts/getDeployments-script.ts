import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const getDeployments = async (_hre: HardhatRuntimeEnvironment) => {
    const { deployments } = _hre;
    const all = await deployments.all();
    return Object.keys(all).map(async (e) => ({ [e]: all[e].address }));
};
