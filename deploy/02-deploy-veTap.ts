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

    console.log('\nDeploying veTap');
    const tapDeployment = await deployments.get('TapOFT');

    const args = [tapDeployment.address, 'veTap Token', 'veTap', '1'];
    await deploy('VeTap', {
        from: deployer,
        log: true,
        args,
    });
    await verify(hre, 'VeTap', args);
    const veTapDeployment = await deployments.get('VeTap');
    contracts.push({
        name: 'VeTap',
        address: veTapDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${veTapDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['VeTap'];
