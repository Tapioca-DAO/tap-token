import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const collectPaymentTokensOnAB__task = async (
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

    const { paymentTokens } = await inquirer.prompt({
        type: 'input',
        name: 'paymentTokens',
        message: 'Payment tokens (split by comma ,)',
    });
    const arr = paymentTokens.split(',');
    await (await ab.collectPaymentTokens(arr)).wait(3);
};
