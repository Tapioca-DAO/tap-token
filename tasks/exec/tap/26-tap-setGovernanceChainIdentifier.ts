import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setGovernanceChainIdentifierOnTap__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(hre, 'TapOFT', tag);
    const tap = await hre.ethers.getContractAt('TapOFT', dep.contract.address);

    const { identifier } = await inquirer.prompt({
        type: 'input',
        name: 'identifier',
        message: 'Governance chain identifier',
    });

    await (await tap.setGovernanceChainIdentifier(identifier)).wait(3);
};
