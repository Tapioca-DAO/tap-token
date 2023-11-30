import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setMinWeightFactorOnTOB__task = async (
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

    const { minWeightFactor } = await inquirer.prompt({
        type: 'input',
        name: 'minWeightFactor',
        message: 'Min weight factor',
    });

    await (await tOB.setMinWeightFactor(minWeightFactor)).wait(3);
};
