import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';

type TNetwork = ReturnType<
    typeof SDK.API.utils.getSupportedChains
>[number]['name'];
export const constants = {
    teamAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    advisorAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    daoAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    otcAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    seedAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    lbpAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    airdropAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    governanceChainId: 421613,
    feeDistributorStartTimestamp: '1677187670', //random
    feeDistributorAdminAddress: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',
    feeDistributorEmergencyReturn: '0x40282d3Cf4890D9806BC1853e97a59C93D813653',

    //------------- TESTNETS --------------
    //goerli
    '5': {
        ...SDK.API.utils.getChainBy('name', 'goerli')!,
        mx_ETH: '0xADCea8173CA63CFeB047Ccedd53045271A6C268b', //mock
    },
    '43113': {
        ...SDK.API.utils.getChainBy('name', 'fuji_avalanche')!,
    },
    '421613': {
        ...SDK.API.utils.getChainBy('name', 'arbitrum_goerli')!,
    },
    '80001': {
        ...SDK.API.utils.getChainBy('name', 'mumbai')!,
    },
    //fantom_testnet
    '4002': {
        ...SDK.API.utils.getChainBy('name', 'fantom_testnet')!,
        mx_ETH: '0xADCea8173CA63CFeB047Ccedd53045271A6C268b', //mock
    },
    //bsc_testnet
    '97': {
        ...SDK.API.utils.getChainBy('name', 'bsc_testnet')!,
    },
    //------------- MAINNETS --------------
};

export const verify = async (
    hre: HardhatRuntimeEnvironment,
    address: string,
    args: any[],
) => {
    console.log(`[+] Verifying ${address}`);
    try {
        await hre.run('verify', {
            address: address,
            constructorArgsParams: args,
        });
        console.log('[+] Verified');
    } catch (err: any) {
        console.log(`[-] failed to verify ${address}; error: ${err.message}\n`);
    }
};

export const updateDeployments = async (
    contracts: TContract[],
    chainId: string,
    tag?: string,
) => {
    SDK.API.db.saveLocally(
        SDK.API.db.buildLocalDeployment({ chainId, contracts }),
        tag,
    );
};

export const registerContract = async (
    hre: HardhatRuntimeEnvironment,
    contractName: string,
    deploymentName: string,
    args: any[],
): Promise<TContract> => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log(`\n[+] Deploying ${contractName} as ${deploymentName}`);
    await deploy(deploymentName, {
        contract: contractName,
        from: deployer,
        log: true,
        args,
    });

    const contract = await deployments.get(deploymentName);
    console.log('[+] Deployed', contractName, 'at', contract.address);
    await verify(hre, contract.address, args);

    const deploymentMeta = {
        name: deploymentName,
        address: contract.address,
        meta: { constructorArguments: args },
    };
    await updateDeployments([deploymentMeta], await hre.getChainId());

    return deploymentMeta;
};
