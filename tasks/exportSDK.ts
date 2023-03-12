import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TLocalDeployment } from 'tapioca-sdk/dist/shared';
/**
 * Script used to generate typings for the tapioca-sdk
 * https://github.com/Tapioca-DAO/tapioca-sdk
 */

export const exportSDK__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    const chainId = await hre.getChainId();
    const deployments = hre.SDK.db.readDeployment(
        'local',
        {},
    ) as TLocalDeployment;

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

    console.log(
        '[+] Exporting typechain & deployment files for tapioca-sdk...',
    );
    console.log(contractNames);

    hre.SDK.exportSDK.run({
        projectCaller: hre.config.SDK.project,
        artifactPath: hre.config.paths.artifacts,
        contractNames,
        deployment: { data: deployments },
    });
};
