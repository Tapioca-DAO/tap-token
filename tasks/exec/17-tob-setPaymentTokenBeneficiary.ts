import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setPaymentTokenBeneficiaryOnTOB__task = async (
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

    const { paymentTokenBeneficiary } = await inquirer.prompt({
        type: 'input',
        name: 'paymentTokenBeneficiary',
        message: 'Payment token beneficiary',
    });

    await (
        await tOB.setPaymentTokenBeneficiary(paymentTokenBeneficiary)
    ).wait(3);
};
