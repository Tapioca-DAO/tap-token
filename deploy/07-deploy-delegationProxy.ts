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

    console.log('\nDeploying DelegationProxy');
    const boostV2Deployment = await deployments.get('BoostV2');
    const args = [boostV2Deployment.address, deployer, deployer];
    await deploy('DelegationProxy', { from: deployer, log: true, args });
    await verify(hre, 'DelegationProxy', args);
    const delegationProxyDeployment = await deployments.get('DelegationProxy');
    contracts.push({
        name: 'DelegationProxy',
        address: delegationProxyDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${delegationProxyDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['DelegationProxy'];
