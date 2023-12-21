import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const initVesting__task = async (taskArgs: {}, hre: HardhatRuntimeEnvironment) => {
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
    const { token } = await inquirer.prompt({
        type: 'input',
        name: 'token',
        message: 'Token address',
    });

    const { amount } = await inquirer.prompt({
        type: 'input',
        name: 'amount',
        message: 'Vesting amount',
    });
    await (await vesting.init(token, amount)).wait(3);
};
