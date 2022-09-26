import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { API } from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';

export const getDeployments = async (_hre: HardhatRuntimeEnvironment, local?: boolean): Promise<TContract[]> => {
    if (local) {
        return JSON.parse(fs.readFileSync(API.utils.PROJECT_RELATIVE_DEPLOYMENT_PATH, 'utf8'))[await _hre.getChainId()];
    }
    return API.utils.getDeployment('Tapioca-Bar', await _hre.getChainId());
};

export const getLocalDeployments__task = async function (taskArgs: any, hre: HardhatRuntimeEnvironment) {
    try {
        console.log(await getDeployments(hre, true));
    } catch (e) {
        console.log('[-] No local deployments found on chain id', await hre.getChainId());
    }
};

export const getSDKDeployments__task = async function (taskArgs: any, hre: HardhatRuntimeEnvironment) {
    try {
        console.log(await getDeployments(hre));
    } catch (e) {
        console.log('[-] No SDK deployments found on chain id', await hre.getChainId());
    }
};
