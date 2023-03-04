import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TProjectDeployment } from 'tapioca-sdk/dist/shared';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';
import { getDeployments } from '../scripts/getDeployments-script';
import { getLocalDeployments__task } from './getDeployments';
/**
 * Script used to generate typings for the tapioca-sdk
 * https://github.com/Tapioca-DAO/tapioca-sdk
 */

export const exportSDK__task = async (taskArgs: { mainnet?: boolean }, hre: HardhatRuntimeEnvironment) => {
    const chainId = await hre.getChainId();

    const _deployments: TProjectDeployment = {
        [chainId as keyof TProjectDeployment]: SDK.API.utils.getDeployments('Tap-Token', chainId, true) ?? [],
    };

    const contractNames = [
        'OFT20',
        'TapOFT',
        'ERC20Mock',
        'OracleMock',
        'OTAP',
        'TapiocaOptionBroker',
        'TapiocaOptionBrokerMock',
        'TapiocaOptionLiquidityProvision',
        'Vesting',
    ];

    console.log('[+] Exporting typechain & deployment files for tapioca-sdk...');
    console.log(contractNames);

    await SDK.API.exportSDK.run({
        artifactPath: hre.config.paths.artifacts,
        projectCaller: 'Tap-Token',
        contractNames,
        _deployments,
    });
};
