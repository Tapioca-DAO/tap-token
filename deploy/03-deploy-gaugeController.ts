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

    console.log('\nDeploying GaugeController');
    const tapDeployment = await deployments.get('TapOFT');
    const veTapDeployment = await deployments.get('VeTap');

    const args = [tapDeployment.address, veTapDeployment.address];
    await deploy('GaugeController', { from: deployer, log: true, args });
    await verify(hre, 'GaugeController', args);
    const gaugeControllerDeployment = await deployments.get('GaugeController');
    contracts.push({
        name: 'GaugeController',
        address: gaugeControllerDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${gaugeControllerDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['GaugeController'];
