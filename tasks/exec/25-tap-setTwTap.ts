import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setTwTapOnTap__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(hre, 'TapOFT', tag);
    const tap = await hre.ethers.getContractAt('TapOFT', dep.contract.address);

    const { twTap } = await inquirer.prompt({
        type: 'input',
        name: 'twTap',
        message: 'twTap address',
    });

    await (await tap.setTwTap(twTap)).wait(3);
};
