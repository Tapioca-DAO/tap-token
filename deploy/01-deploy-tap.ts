import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { constants, verify, updateDeployments } from '../scripts/deployment.utils';
import { TContract } from 'tapioca-sdk/dist/shared';
import { TapOFT, TapOFT__factory } from '../typechain';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    //all of these should be constants
    const lzEndpoint = constants[chainId as '5'].address as string;
    const contributorAddress = constants.teamAddress;
    const investorAddress = constants.advisorAddress;
    const lbpAddress = constants.daoAddress;
    const airdropAddress = constants.seedAddress;
    const daoAddress = constants.daoAddress;
    const governanceChainId = constants.governanceChainId.toString();
    const args: Parameters<TapOFT__factory['deploy']> = [
        lzEndpoint,
        contributorAddress,
        investorAddress,
        lbpAddress,
        daoAddress,
        airdropAddress,
        governanceChainId,
    ];

    console.log('\nDeploying TapOFT');
    await deploy('TapOFT', {
        from: deployer,
        log: true,
        args,
        // gasPrice: '20000000000',
    });
    const tapOFTDeployment = await deployments.get('TapOFT');
    await verify(hre, tapOFTDeployment.address, args);
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
