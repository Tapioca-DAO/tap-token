import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';
import { TapiocaOptionBroker, TapiocaOptionBrokerMock, TapiocaOptionBroker__factory } from '../typechain';
import { updateDeployments, verify } from '../scripts/deployment.utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();

    const contracts: TContract[] = [];

    const tapOFT = SDK.API.utils.getDeployment('Tap-Token', 'TapOFT', chainId).address;
    const oTAP = SDK.API.utils.getDeployment('Tap-Token', 'OTAP', chainId).address;
    const tOLP = SDK.API.utils.getDeployment('Tap-Token', 'TapiocaOptionLiquidityProvision', chainId).address;

    const paymentTokenBeneficiary = deployer;
    const tapOracle = '0xBaC59400ED43d56ea9b74C79D633d8FBC3FA43A4'; // Goerli Oracle Mock

    //all of these should be constants
    const args: Parameters<TapiocaOptionBroker__factory['deploy']> = [tOLP, oTAP, tapOFT, tapOracle, paymentTokenBeneficiary];

    console.log('\nDeploying tOB');
    const deploymentName = hre.network.tags['testnet'] ? 'TapiocaOptionBrokerMock' : 'TapiocaOptionBroker';
    await deploy(deploymentName, {
        from: deployer,
        log: true,
        args,
        // gasPrice: '20000000000',
    });
    const tOBDeployment = await deployments.get(deploymentName);
    await verify(hre, tOBDeployment.address, args);
    contracts.push({
        name: deploymentName,
        address: tOBDeployment.address,
        meta: { constructorArguments: args },
    });

    const tap = await hre.ethers.getContractAt('TapOFT', tapOFT);
    if ((await tap.minter()) !== tOBDeployment.address) {
        console.log('[+] Setting tOB as minter for TapOFT');
        await (await tap.setMinter(tOBDeployment.address)).wait();
    }

    const tOB = (await hre.ethers.getContractAt(deploymentName, tOBDeployment.address)) as TapiocaOptionBroker | TapiocaOptionBrokerMock;
    const oTAPcontract = await hre.ethers.getContractAt('OTAP', oTAP);
    if ((await oTAPcontract.broker()) !== tOBDeployment.address) {
        console.log('[+] Claiming oTAP broker role on tOB');
        await (await tOB.oTAPBrokerClaim()).wait();
    }

    console.log(`Done. Deployed on ${tOBDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['TapiocaOptionBroker', 'tOB'];
