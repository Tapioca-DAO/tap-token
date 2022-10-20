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

    console.log('\nDeploying BoostV2');
    const veTapDeployment = await deployments.get('VeTap');
    const args = [veTapDeployment.address];
    await deploy('BoostV2', { from: deployer, log: true, args });
    await verify(hre, 'BoostV2', args);
    const boostV2Deployment = await deployments.get('BoostV2');
    contracts.push({
        name: 'BoostV2',
        address: boostV2Deployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${boostV2Deployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['BoostV2'];
