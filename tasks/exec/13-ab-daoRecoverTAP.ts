import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';

export const daoRecoverTAPFromAB__task = async (
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

    await (await ab.daoRecoverTAP()).wait(3);
};
