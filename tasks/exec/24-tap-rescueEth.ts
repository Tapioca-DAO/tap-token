import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const rescueEthOnTap__task = async (
    taskArgs: {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(hre, 'TapOFT', tag);
    const tap = await hre.ethers.getContractAt('TapOFT', dep.contract.address);

    const { amount } = await inquirer.prompt({
        type: 'input',
        name: 'amount',
        message: 'Rescue amount',
    });

    const { to } = await inquirer.prompt({
        type: 'input',
        name: 'to',
        message: 'Receiver',
    });

    await (await tap.rescueEth(amount, to)).wait(3);
};
