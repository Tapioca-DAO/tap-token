import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { verify, updateDeployments } from './utils';
import { TContract } from 'tapioca-sdk/dist/shared';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    console.log('\nDeploying GaugeDistributor');
    const tapDeployment = await deployments.get('TapOFT');
    const gaugeControllerDeployment = await deployments.get('GaugeController');
    const args = [tapDeployment.address, gaugeControllerDeployment.address];
    await deploy('GaugeDistributor', { from: deployer, log: true, args });
    await verify(hre, 'GaugeDistributor', args);
    const gaugeDistributorDeployment = await deployments.get('GaugeDistributor');
    contracts.push({
        name: 'GaugeDistributor',
        address: gaugeDistributorDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${gaugeDistributorDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['GaugeDistributor'];
