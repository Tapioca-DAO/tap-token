import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { TapOFT } from '../typechain';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log(`Deploying on ${hre.network.name} (id: ${hre.network.config.chainId}; )...`);
    console.log(`Deploying from ${deployer}`);

    const lzEndpoint = process.env[`LZENDPOINT_${hre.network.name}`];
    const feeDistributorContract = await deployments.get('FeeDistributor');

    const args = [lzEndpoint, feeDistributorContract.address, deployer];
    await deploy('esTapOFT', {
        from: deployer,
        log: true,
        args,
    });

    const esTapOFTDeployment = await deployments.get('esTapOFT');
    try {
        await hre.run('verify', {
            address: esTapOFTDeployment.address,
            constructorArgsParams: args,
        });
    } catch (err: any) {
        console.log(`Error: ${err.message}\n`);
    }
};

export default func;
func.tags = ['esTapOFT'];
