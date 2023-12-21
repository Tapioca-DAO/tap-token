import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setPhase2MerkleRoots__task = async (
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

    const { merkleRoots } = await inquirer.prompt({
        type: 'input',
        name: 'merkleRoots',
        message: 'Merkle roots',
    });

    await (await ab.setPhase2MerkleRoots(merkleRoots)).wait(3);
};
