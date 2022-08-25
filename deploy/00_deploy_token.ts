import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { TapOFT } from '../typechain';

// Test deployments:
// https://rinkeby.etherscan.io/address/0xb12a083D817534D19b1849158E189d0032316F7c
// https://mumbai.polygonscan.com/address/0xd4ad027085B0F82B0E7D7b6D67d195B6C8b074a9#code

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    //all of these should be constants
    const lzEndpoint = process.env[`LZENDPOINT_${hre.network.name}`];
    const teamAddress = process.env.PUBLIC_KEY;
    const advisorsAddress = process.env.PUBLIC_KEY;
    const globalIncentivesAddress = process.env.PUBLIC_KEY;
    const initialDexLiquidityAddress = process.env.PUBLIC_KEY;
    const seedAddress = process.env.PUBLIC_KEY;
    const privateAddress = process.env.PUBLIC_KEY;
    const idoAddress = process.env.PUBLIC_KEY;
    const airdropAddress = process.env.PUBLIC_KEY;
    const governanceChainId = 10001;

    console.log(`Deploying on ${hre.network.name} (id: ${hre.network.config.chainId}; )...`);
    console.log(`Deploying from ${deployer}`);

    const args = [
        lzEndpoint,
        teamAddress,
        advisorsAddress,
        globalIncentivesAddress,
        initialDexLiquidityAddress,
        seedAddress,
        privateAddress,
        idoAddress,
        airdropAddress,
        governanceChainId.toString(),
    ];

    await deploy('TapOFT', {
        from: deployer,
        log: true,
        args,
    });

    const tapOFTDeployment = await deployments.get('TapOFT');
    const tapOFTContract = (await ethers.getContractAt('TapOFT', tapOFTDeployment.address)) as TapOFT;

    // const latestBlock = await ethers.provider.getBlock('latest');
    // let overrides = {
    //     value: ethers.utils.parseEther('1.4'),
    // };
    // console.log('locking');
    // await tapOFTContract.getVotingPower(ethers.utils.parseEther('1000'), latestBlock.timestamp + 2 * 365 * 86400, overrides);
    // return;

    try {
        await hre.run('verify', {
            address: tapOFTDeployment.address,
            constructorArgsParams: args,
        });
    } catch (err: any) {
        console.log(`Error: ${err.message}\n`);
    }
};

export default func;
func.tags = ['TapOFT'];
