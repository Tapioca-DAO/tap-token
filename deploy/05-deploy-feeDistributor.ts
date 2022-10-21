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

    console.log('\nDeploying FeeDistributor');
    const tapDeployment = await deployments.get('TapOFT');
    const veTapDeployment = await deployments.get('VeTap');
    const args = [
        veTapDeployment.address,
        constants.feeDistributorStartTimestamp,
        tapDeployment.address,
        constants.feeDistributorAdminAddress,
        constants.feeDistributorEmergencyReturn,
    ];
    await deploy('FeeDistributor', { from: deployer, log: true, args });
    await verify(hre, 'FeeDistributor', args);
    const feeDistributorDeployment = await deployments.get('FeeDistributor');
    contracts.push({
        name: 'FeeDistributor',
        address: feeDistributorDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${feeDistributorDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['FeeDistributor'];
