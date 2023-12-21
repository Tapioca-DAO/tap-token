import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const collectPaymentTokensOnTOB__task = async (
    {},
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

    const { paymentTokens } = await inquirer.prompt({
        type: 'input',
        name: 'paymentTokens',
        message: 'Payment tokens (split by comma ,)',
    });
    const arr = paymentTokens.split(',');
    await (await tOB.collectPaymentTokens(arr)).wait(3);
};
