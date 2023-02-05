import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';
import { TapiocaOptionLiquidityProvision__factory } from '../typechain';
import { updateDeployments, verify } from '../scripts/deployment.utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    // const tapOFT = await hre.ethers.getContractAt('TapOFT', (await SDK.API.utils.getDeployment('Tap-Token', 'TapOFT', chainId)).address);

    //all of these should be constants
    const yieldBox = (await SDK.API.utils.getDeployment('Tapioca-Bar', 'YieldBox', chainId)).address;
    const args: Parameters<TapiocaOptionLiquidityProvision__factory['deploy']> = [yieldBox];

    console.log('\nDeploying tOLP');
    await deploy('TapiocaOptionLiquidityProvision', {
        from: deployer,
        log: true,
        args,
        // gasPrice: '20000000000',
    });
    const tOLPDeployment = await deployments.get('TapiocaOptionLiquidityProvision');
    await verify(hre, tOLPDeployment.address, args);
    contracts.push({
        name: 'TapiocaOptionLiquidityProvision',
        address: tOLPDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${tOLPDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['TapiocaOptionLiquidityProvision', 'tOLP'];
