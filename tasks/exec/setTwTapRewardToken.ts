import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';

export const setTwTapRewardToken__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');

    const twTAPDep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TwTAP',
        tag,
    );
    const twTAP = await hre.ethers.getContractAt(
        'TwTAP',
        twTAPDep.contract.address,
    );

    const { rewardTokenAddress } = await inquirer.prompt({
        type: 'input',
        name: 'rewardTokenAddress',
        message: 'Choose the reward token address',
    });

    const tx = await twTAP.addRewardToken(rewardTokenAddress);
    console.log(`[+] Setting twTAP reward token to ${rewardTokenAddress}`);
    console.log('[+] Transaction hash: ', tx.hash);
    await tx.wait(3);
};
