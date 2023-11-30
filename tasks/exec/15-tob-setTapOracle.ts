import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setTapOracleOnTOB__task = async (
    taskArgs: {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TapiocaOptionBroker',
        tag,
    );
    const tOB = await hre.ethers.getContractAt(
        'TapiocaOptionBroker',
        dep.contract.address,
    );

    const { tapOracle } = await inquirer.prompt({
        type: 'input',
        name: 'tapOracle',
        message: 'TapOracle address',
    });

    const { tapOracleData } = await inquirer.prompt({
        type: 'input',
        name: 'tapOracleData',
        message: 'TapOracle data',
    });

    await (await tOB.setTapOracle(tapOracle, tapOracleData)).wait(3);
};
