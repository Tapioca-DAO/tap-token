import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setMaxRewardTokensLength__task = async (
    taskArgs: {},
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
    const { length } = await inquirer.prompt({
        type: 'input',
        name: 'length',
        message: 'Max length',
    });
    await (await twTAP.setMaxRewardTokensLength(length)).wait(3);
};
