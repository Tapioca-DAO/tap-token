import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { constants, verify, updateDeployments } from './utils';
import { TContract } from 'tapioca-sdk/dist/shared';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    //all of these should be constants
    const lzEndpoint = constants[chainId].address;
    const teamAddress = constants.teamAddress;
    const advisorAddress = constants.advisorAddress;
    const daoAddress = constants.daoAddress;
    const seedAddress = constants.seedAddress;
    const otcAddress = constants.otcAddress;
    const lbpAddress = constants.lbpAddress;
    const governanceChainId = constants.governanceChainId.toString();
    const args = [lzEndpoint, teamAddress, advisorAddress, daoAddress, seedAddress, otcAddress, lbpAddress, governanceChainId];

    console.log('\nDeploying TapOFT');
    await deploy('TapOFT', {
        from: deployer,
        log: true,
        args,
    });
    await verify(hre, 'TapOFT', args);
    const tapOFTDeployment = await deployments.get('TapOFT');
    contracts.push({
        name: 'TapOFT',
        address: tapOFTDeployment.address,
        meta: { constructorArguments: args },
    });
    console.log(`Done. Deployed on ${tapOFTDeployment.address} with args ${args}`);

    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['TapOFT'];
