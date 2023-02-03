import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';

const supportedChains: { [key: string]: any } = SDK.API.utils.getSupportedChains().reduce(
    (sdkChains, chain) => ({
        ...sdkChains,
        [chain.name]: {
            ...chain,
        },
    }),
    {},
);

export const constants: { [key: string]: any } = {
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
        ...supportedChains['goerli'],
        mx_ETH: '0xADCea8173CA63CFeB047Ccedd53045271A6C268b', //mock
    },
    '43113': {
        ...supportedChains['fuji_avalanche'],
    },
    '421613': {
        ...supportedChains['arbitrum_goerli'],
    },
    '80001': {
        ...supportedChains['mumbai'],
    },
    //fantom_testnet
    '4002': {
        ...supportedChains['fantom_testnet'],
        mx_ETH: '0xADCea8173CA63CFeB047Ccedd53045271A6C268b', //mock
    },
    //------------- MAINNETS --------------
};

export const verify = async (hre: HardhatRuntimeEnvironment, artifact: string, args: any[]) => {
    const { deployments } = hre;

    const deployed = await deployments.get(artifact);
    console.log(`[+] Verifying ${artifact}`);
    try {
        await hre.run('verify', {
            address: deployed.address,
            constructorArgsParams: args,
        });
        console.log('[+] Verified');
    } catch (err: any) {
        console.log(`[-] failed to verify ${artifact}; error: ${err.message}\n`);
    }
};

export const updateDeployments = async (contracts: TContract[], chainId: string) => {
    await SDK.API.utils.saveDeploymentOnDisk({
        [chainId]: contracts,
    });
};

export const registerVesting = async (
    hre: HardhatRuntimeEnvironment,
    token: string,
    cliff: string,
    duration: string,
): Promise<TContract> => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log('\n Deploying Vesting');
    const args = [token, cliff, duration];
    await deploy('Vesting', {
        from: deployer,
        log: true,
        args,
    });
    await verify(hre, 'Vesting', args);
    const vestingContract = await deployments.get('Vesting');
    console.log('Done');

    return new Promise(async (resolve) =>
        resolve({
            name: 'Vesting',
            address: vestingContract.address,
            meta: { constructorArguments: args },
        }),
    );
};
