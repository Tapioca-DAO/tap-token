import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TLocalDeployment } from 'tapioca-sdk/dist/shared';

// TODO - Put in SDK
export const exportSDK__task = async (
    taskArgs: { tag?: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log(
        '\n\n[+] Exporting typechain & deployment files for tapioca-sdk...',
    );
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const data = hre.SDK.db.readDeployment('local', {
        tag,
    }) as TLocalDeployment;

    if (!tag) {
        console.log('[-] No local deployment found. Skipping to typechain');
    }

    const allContracts = (await hre.artifacts.getAllFullyQualifiedNames())
        .filter((e) => e.startsWith('contracts/'))
        .map((e) => e.split(':')[1])
        .filter((e) => e[0] !== 'I');

    const { contractNames } = await inquirer.prompt({
        type: 'checkbox',
        message: 'Select contracts to export',
        name: 'contractNames',
        choices: allContracts,
        default: allContracts,
    });

    console.log(
        '[+] Exporting typechain & deployment files for tapioca-sdk...',
    );

    hre.SDK.exportSDK.run({
        projectCaller: hre.config.SDK.project,
        artifactPath: hre.config.paths.artifacts,
        deployment: { data, tag },
        contractNames,
    });
};
