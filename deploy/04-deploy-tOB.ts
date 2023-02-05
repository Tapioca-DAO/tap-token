import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';
import { TapiocaOptionBroker__factory, TapiocaOptionLiquidityProvision__factory } from '../typechain';
import { updateDeployments, verify } from '../scripts/deployment.utils';

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
    const tapOracle = '0xBaC59400ED43d56ea9b74C79D633d8FBC3FA43A4'; // Goerli Oracle Mock

    //all of these should be constants
    const args: Parameters<TapiocaOptionBroker__factory['deploy']> = [tOLP, oTAP, tapOFT, tapOracle, paymentTokenBeneficiary];

    console.log('\nDeploying tOB');
    await deploy('TapiocaOptionBroker', {
        from: deployer,
        log: true,
        args,
        // gasPrice: '20000000000',
    });
    const tOBDeployment = await deployments.get('TapiocaOptionBroker');
    await verify(hre, tOBDeployment.address, args);
    contracts.push({
        name: 'TapiocaOptionBroker',
        address: tOBDeployment.address,
        meta: { constructorArguments: args },
    });

    const tap = await hre.ethers.getContractAt('TapOFT', (await SDK.API.utils.getDeployment('Tap-Token', 'TapOFT', chainId)).address);
    if ((await tap.minter()) !== tOBDeployment.address) {
        console.log('[+] Setting tOB as minter for TapOFT');
        await tap.setMinter(tOBDeployment.address);
    }

    const tOB = await hre.ethers.getContractAt('TapiocaOptionBroker', tOBDeployment.address);
    const oTAPcontract = await hre.ethers.getContractAt('OTAP', oTAP);
    if ((await oTAPcontract.broker()) !== tOBDeployment.address) {
        console.log('[+] Claiming oTAP broker role on tOB');
        await tOB.oTAPBrokerClaim();
    }

    console.log(`Done. Deployed on ${tOBDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['TapiocaOptionBroker', 'tOB'];
