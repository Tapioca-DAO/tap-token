import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TAPIOCA_PROJECTS_NAME } from '../../gitsub_tapioca-sdk/src/api/config';
import { Singularity__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-bar/factories/markets/singularity';
import { TContract } from 'tapioca-sdk/dist/shared';

export const setRegisterTapOracle__task = async (
    {},
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

    const { tapOracle } = await inquirer.prompt({
        type: 'input',
        name: 'tapOracle',
        message: 'Choose a TapOracle address',
    });

    const { tapOracleData } = await inquirer.prompt({
        type: 'input',
        name: 'tapOracleData',
        message: 'Choose the data for the oracle',
    });

    const tx = await tOB.setTapOracle(tapOracle, tapOracleData);
    console.log(
        `[+] Setting tOB Tap oracle to ${tapOracle} with data ${tapOracleData}`,
    );
    console.log('[+] Transaction hash: ', tx.hash);
    await tx.wait(3);
};
