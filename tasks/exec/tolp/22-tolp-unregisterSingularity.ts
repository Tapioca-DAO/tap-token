import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const unregisterSingularityOnTOLP__task = async (
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

    await (await tOLP.unregisterSingularity(singularity)).wait(3);
};
