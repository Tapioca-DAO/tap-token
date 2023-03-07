import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';
import { OTAP__factory } from '../typechain';
import { updateDeployments, verify } from '../scripts/deployment.utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    //all of these should be constants
    const args: Parameters<OTAP__factory['deploy']> = [];

    console.log('\nDeploying oTAP');
    await deploy('OTAP', {
        from: deployer,
        log: true,
        args,
        // gasPrice: '20000000000',
    });
    const oTAPDeployment = await deployments.get('OTAP');
    await verify(hre, oTAPDeployment.address, args);
    contracts.push({
        name: 'OTAP',
        address: oTAPDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(
        `Done. Deployed on ${oTAPDeployment.address} with args ${args}`,
    );

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['OTAP', 'oTAP'];
