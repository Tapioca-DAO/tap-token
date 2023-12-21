import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TAPIOCA_PROJECTS_NAME } from '../../gitsub_tapioca-sdk/src/api/config';
import { Singularity__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-bar/factories/markets/singularity';
import { TContract } from 'tapioca-sdk/dist/shared';

export const setPaymentTokenOnTOB__task = async (
    taskArgs: {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');

    const tOBDep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TapiocaOptionBroker',
        tag,
    );
    const tOB = await hre.ethers.getContractAt(
        'TapiocaOptionBroker',
        tOBDep.contract.address,
    );

    const { paymentToken } = await inquirer.prompt({
        type: 'input',
        name: 'paymentToken',
        message: 'Choose the payment token address',
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

    const tx = await tOB.setPaymentToken(
        paymentToken,
        paymentTokenOracle,
        paymentTokenData,
    );
    const token = hre.ethers.getContractAt('ERC20', paymentToken);

    console.log(
        `[+] Setting tOB payment token to ${(
            await token
        ).name()}:${paymentToken}`,
    );
    console.log('[+] Transaction hash: ', tx.hash);
    await tx.wait(3);
};
