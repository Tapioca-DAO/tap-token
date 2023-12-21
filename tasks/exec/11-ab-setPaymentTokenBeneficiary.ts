import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setPaymentTokenBeneficiaryAB__task = async (
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

    const { paymentTokenBeneficiary } = await inquirer.prompt({
        type: 'input',
        name: 'paymentTokenBeneficiary',
        message: 'Payment token beneficiary',
    });

    await (
        await ab.setPaymentTokenBeneficiary(paymentTokenBeneficiary)
    ).wait(3);
};
