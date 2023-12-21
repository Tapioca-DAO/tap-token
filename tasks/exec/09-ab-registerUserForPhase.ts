import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const registerUserForPhase__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'AirdropBroker',
        tag,
    );
    const ab = await hre.ethers.getContractAt(
        'AirdropBroker',
        dep.contract.address,
    );

    const { phase } = await inquirer.prompt({
        type: 'input',
        name: 'phase',
        message: 'Airdrop phase',
    });

    const { users } = await inquirer.prompt({
        type: 'input',
        name: 'users',
        message: 'Users addresses (split by comma , )',
    });

    const { amounts } = await inquirer.prompt({
        type: 'input',
        name: 'amounts',
        message: 'Users amounts (split by comma , )',
    });

    const usersArray = users.split(',');
    const usersAmounts = amounts.split(',');
    if (usersArray.length == usersAmounts.length)
        throw new Error('[-] Length mismatch');

    await (
        await ab.registerUserForPhase(phase, usersArray, usersAmounts)
    ).wait(3);
};
