import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setLockedUntilOnLtap__task = async (
    taskArgs: {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(hre, 'LTap', tag);
    const ltap = await hre.ethers.getContractAt('LTap', dep.contract.address);

    const { lockedUntil } = await inquirer.prompt({
        type: 'input',
        name: 'lockedUntil',
        message: 'Locked until',
    });

    await (await ltap.setLockedUntil(lockedUntil)).wait(3);
};
