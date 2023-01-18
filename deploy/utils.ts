import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';

let supportedChains: { [key: string]: any } = SDK.API.utils.getSupportedChains().reduce(
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

export const deployGauge = async (hre: HardhatRuntimeEnvironment, taskArgs: any): Promise<TContract> => {
    const { deployments } = hre;
    const chainId = await hre.getChainId();

    console.log('\nDeploying LiquidityGauge');

    const marketName = taskArgs.name.toUpperCase();
    const gaugeFactory = await deployments.get('GaugeFactory');
    const gaugeDistributor = await deployments.get('GaugeDistributor');
    const tapToken = await deployments.get('TapOFT');
    const mxToken = constants[chainId][`mx_${marketName}`];
    const gaugeFactoryContract = await hre.ethers.getContractAt('GaugeFactory', gaugeFactory.address);

    const args = [mxToken, tapToken.address, gaugeDistributor.address];

    const createGaugeTx = await gaugeFactoryContract.createGauge(mxToken, tapToken.address, gaugeDistributor.address);
    const createGaugeRc = await createGaugeTx.wait();

    const createdGauge = createGaugeRc.events!.filter((a: any) => a.event == 'GaugeCreated')[0].args![1];
    console.log(`Done. Deployed on ${createdGauge.address} with args ${args}`);

    return new Promise(async (resolve) =>
        resolve({
            name: `gauge_${marketName}`,
            address: createdGauge.address,
            meta: { constructorArguments: args },
        }),
    );
};
