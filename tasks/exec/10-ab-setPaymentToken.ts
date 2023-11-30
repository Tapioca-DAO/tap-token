import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setPaymentTokenOnAB__task = async (
    taskArgs: {},
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

    const { paymentToken } = await inquirer.prompt({
        type: 'input',
        name: 'paymentToken',
        message: 'Payment token',
    });

    const { paymentTokenOracle } = await inquirer.prompt({
        type: 'input',
        name: 'paymentTokenOracle',
        message: 'Choose the oracle address of the payment token',
    });

    const { paymentTokenData } = await inquirer.prompt({
        type: 'input',
        name: 'paymentTokenData',
        message: 'Choose the payment token oracle data',
    });

    const tx = await ab.setPaymentToken(
        paymentToken,
        paymentTokenOracle,
        paymentTokenData,
    );
    const token = hre.ethers.getContractAt('ERC20', paymentToken);

    console.log(
        `[+] Setting AB payment token to ${(
            await token
        ).name()}:${paymentToken}`,
    );
    console.log('[+] Transaction hash: ', tx.hash);
    await tx.wait(3);
};
