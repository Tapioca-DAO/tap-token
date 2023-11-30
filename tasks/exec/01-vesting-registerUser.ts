import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const registerUserForVesting__task = async (
    taskArgs: {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const vestingDep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'Vesting',
        tag,
    );
    const vesting = await hre.ethers.getContractAt(
        'Vesting',
        vestingDep.contract.address,
    );

    const { user } = await inquirer.prompt({
        type: 'input',
        name: 'user',
        message: 'User address',
    });

    const { amount } = await inquirer.prompt({
        type: 'input',
        name: 'amount',
        message: 'Vesting amount',
    });

    await (await vesting.registerUser(user, amount)).wait(3);
};
