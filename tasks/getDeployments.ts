import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';

export const getDeployments = async (hre: HardhatRuntimeEnvironment, local?: boolean): Promise<TContract[]> => {
    return SDK.API.utils.getDeployments('Tap-Token', await hre.getChainId(), Boolean(local)) ?? [];
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
