import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';

export const setDistributeTwTapRewards__task = async (
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

    const { rewardTokenID } = await inquirer.prompt({
        type: 'input',
        name: 'rewardTokenID',
        message: 'Choose the reward token ID',
    });

    const amount = hre.ethers.utils.parseEther('0.1');

    const rewardToken = await hre.ethers.getContractAt(
        'ERC20',
        await twTAP.rewardTokens(rewardTokenID),
    );
    await (await rewardToken.approve(twTAP.address, amount)).wait(3);
    const tx = await twTAP.distributeReward(rewardTokenID, amount);

    console.log(`[+] Distributing twTAP reward token to ${rewardTokenID}`);
    console.log('[+] Transaction hash: ', tx.hash);
    await tx.wait(3);
};
