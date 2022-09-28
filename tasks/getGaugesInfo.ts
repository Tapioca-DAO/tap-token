import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import { getGaugeContract, getGaugeControllerContract } from './utils';

//Execution example:
//      npx hardhat getGaugesInfo --gauge "<address>"
export const getInfo = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { gaugeContract, gaugeAddress } = await getGaugeContract(taskArgs, hre);
    const { gaugeControllerContract } = await getGaugeControllerContract(hre);

    const gaugeControllerInterface = await hre.ethers.getContractAt('IGaugeController', gaugeControllerContract.address);

    const rewardDuration = await gaugeContract.rewardsDuration();
    const periodFinish = await gaugeContract.periodFinish();
    const rewardPerToken = await gaugeContract.rewardPerToken();
    const totalSupply = await gaugeContract.totalSupply();

    const gaugeType = await gaugeControllerContract.gauge_types(gaugeAddress);
    const gaugeWeight = await gaugeControllerContract.get_gauge_weight(gaugeAddress);
    const gaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(gaugeAddress);

    return {
        rewardDuration: rewardDuration,
        periodFinish: periodFinish,
        rewardPerToken: rewardPerToken,
        totalSupply: totalSupply,
        gaugeType: gaugeType,
        gaugeWeight: gaugeWeight,
        gaugeRelativeWeight: gaugeRelativeWeight,
    };
};

export const getGaugesInfo__task = async (args: any, hre: HardhatRuntimeEnvironment) => {
    console.log(await getInfo(args, hre));
};
