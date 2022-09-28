import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import { getBoostContract, getGaugeContract, getGaugeControllerContract, getTapContract, getVotingEscrowContract } from './utils';

//Execution example:
//      npx hardhat getGaugesInfo --user "<address>" --gauge "<address>"
//      npx hardhat getGaugesInfo --user "<address>"
export const getInfo = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const { gaugeContract, gaugeAddress } = await getGaugeContract(taskArgs, hre);
    const { gaugeControllerContract } = await getGaugeControllerContract(hre);
    const { votingEscrowContract } = await getVotingEscrowContract(hre);
    const { boostContract } = await getBoostContract(hre);
    const { tapOFTContract } = await getTapContract(hre);

    const userAddress = taskArgs['user'];
    if (!hre.ethers.utils.isAddress(userAddress)) {
        throw new Error('[-] User address not valid');
    }

    const ierc20Ve = await hre.ethers.getContractAt('IOFT', votingEscrowContract.address);

    const lastSlope = await votingEscrowContract.get_last_user_slope(userAddress);
    const lockEndDate = await votingEscrowContract.locked__end(userAddress);
    const totalTapBalance = await tapOFTContract.balanceOf(userAddress);
    const totalVeTapBalance = await ierc20Ve.balanceOf(userAddress);
    const totalPowerUsed = await gaugeControllerContract.vote_user_power(userAddress);
    const totalDelegable = await boostContract.delegable_balance(userAddress);
    const totalReceived = await boostContract.received_balance(userAddress);

    const returnable = {
        lastSlope: lastSlope,
        lockEndDate: lockEndDate,
        totalTapBalance: totalTapBalance,
        totalVeTapBalance: totalVeTapBalance,
        totalPowerUsed: totalPowerUsed,
        totalDelegable: totalDelegable,
        totalReceived: totalReceived,
    };

    const gaugeInfo: any = {};
    if (hre.ethers.utils.isAddress(gaugeAddress)) {
        gaugeInfo.gaugeBalance = await gaugeContract.balanceOf(userAddress);
        gaugeInfo.accruedRewards = await gaugeContract.earned(userAddress);
    }
    return { ...returnable, ...gaugeInfo };
};

export const getGaugesInfo__task = async (args: any, hre: HardhatRuntimeEnvironment) => {
    console.log(await getInfo(args, hre));
};
