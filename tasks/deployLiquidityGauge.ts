import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { deployGauge, updateDeployments } from '../deploy/utils';

export const deployGauge__task = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const gaugeObj = await deployGauge(hre, taskArgs);
    await updateDeployments([gaugeObj], await hre.getChainId());
};
