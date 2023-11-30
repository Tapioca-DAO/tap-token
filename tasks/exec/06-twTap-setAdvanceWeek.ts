import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';

export const setAdvanceWeek__task = async (
    taskArgs: {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');

    const twTAPDep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TwTAP',
        tag,
    );
    const twTAP = await hre.ethers.getContractAt(
        'TwTAP',
        twTAPDep.contract.address,
    );
    const tx = await twTAP.advanceWeek(50);
    console.log('[+] Advancing week by a max of 50');
    console.log('[+] Transaction hash: ', tx.hash);
    await tx.wait(3);
};
