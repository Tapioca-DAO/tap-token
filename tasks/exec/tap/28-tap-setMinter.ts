import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setMinterOnTap__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(hre, 'TapOFT', tag);
    const tap = await hre.ethers.getContractAt('TapOFT', dep.contract.address);

    const { minter } = await inquirer.prompt({
        type: 'input',
        name: 'minter',
        message: 'Minter address',
    });

    await (await tap.setMinter(minter)).wait(3);
};
