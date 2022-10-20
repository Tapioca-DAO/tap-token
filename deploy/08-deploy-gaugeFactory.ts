import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { verify, updateDeployments, constants } from './utils';
import { TContract } from 'tapioca-sdk/dist/shared';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    console.log('\nDeploying Gauge');
    await deploy('TimedGauge', { from: deployer, log: true });
    await verify(hre, 'TimedGauge', []);
    const timedGaugeDeployment = await deployments.get('TimedGauge');
    console.log(`Done. Deployed on ${timedGaugeDeployment.address} with no arguments`);
    contracts.push({
        name: 'TimedGauge',
        address: timedGaugeDeployment.address,
        meta: {},
    });

    console.log('\nDeploying GaugeFactory');
    const args = [timedGaugeDeployment.address];
    await deploy('GaugeFactory', { from: deployer, log: true, args });
    await verify(hre, 'GaugeFactory', args);
    const gaugeFactoryDeployment = await deployments.get('GaugeFactory');
    contracts.push({
        name: 'GaugeFactory',
        address: gaugeFactoryDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${gaugeFactoryDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['GaugeFactory'];
