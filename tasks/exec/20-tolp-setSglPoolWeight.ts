import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setSglPoolWeightOnTOLP__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TapiocaOptionLiquidityProvision',
        tag,
    );
    const tOLP = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        dep.contract.address,
    );

    const { singularity } = await inquirer.prompt({
        type: 'input',
        name: 'singularity',
        message: 'Singularity address',
    });

    const { weight } = await inquirer.prompt({
        type: 'input',
        name: 'weight',
        message: 'Singularity weight',
    });

    await (await tOLP.setSGLPoolWEight(singularity, weight)).wait(3);
};
