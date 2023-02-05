import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';
import { TapiocaOptionBroker__factory, TapiocaOptionLiquidityProvision__factory } from '../typechain';
import { updateDeployments, verify } from './utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    const tapOFT = (await SDK.API.utils.getDeployment('Tap-Token', 'TapOFT', chainId)).address;
    const oTAP = (await SDK.API.utils.getDeployment('Tap-Token', 'OTAP', chainId)).address;
    const tOLP = (await SDK.API.utils.getDeployment('Tap-Token', 'TapiocaOptionLiquidityProvision', chainId)).address;

    const paymentTokenBeneficiary = deployer;
    const tapOracle = (await SDK.API.utils.getDeployment('Tap-Token', 'TaptapOracle', chainId)).address;

    //all of these should be constants
    const args: Parameters<TapiocaOptionBroker__factory['deploy']> = [tOLP, oTAP, tapOFT, tapOracle, paymentTokenBeneficiary];

    console.log('\nDeploying tOB');
    await deploy('TapiocaOptionBroker', {
        from: deployer,
        log: true,
        args,
        // gasPrice: '20000000000',
    });
    await verify(hre, 'TapiocaOptionBroker', args);
    const tOBDeployment = await deployments.get('TapiocaOptionBroker');
    contracts.push({
        name: 'TapiocaOptionBroker',
        address: tOBDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${tOBDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['TapiocaOptionBroker', 'tOB'];
