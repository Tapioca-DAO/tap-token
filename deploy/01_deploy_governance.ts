import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

// VeTap test: https://rinkeby.etherscan.io/address/0xAEACDCA87FD3A128fd579C7F197c40EBA104810e

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    //get token
    const tapOFTDeployment = await deployments.get('TapOFT');
    const tapOFTContract = await ethers.getContractAt('TapOFT', tapOFTDeployment.address);

    //deploy veTap
    console.log('   Deploying veTap...');
    const veTapDeployArgs = [tapOFTDeployment.address, 'veTap Token', 'veTap', '1'];
    await deploy('VeTap', {
        from: deployer,
        log: true,
        args: veTapDeployArgs,
    });
    const veTapContract = await deployments.get('VeTap');
    try {
        await hre.run('verify', {
            address: veTapContract.address,
            constructorArgsParams: veTapDeployArgs,
        });
    } catch (err) {
        console.log(err);
    }


    //deploy GaugeController
    console.log('   Deploying GaugeController...');
    const gaugeContollerDeployArgs = [tapOFTDeployment.address, veTapContract.address];
    await deploy('GaugeController', { from: deployer, log: true, args: gaugeContollerDeployArgs });
    const gaugeControllerContract = await deployments.get('GaugeController');

    //deploy minter
    console.log('   Deploying Gauge Distributor...');
    const minterDeployArgs = [tapOFTDeployment.address, gaugeControllerContract.address];
    await deploy('GaugeDistributor', { from: deployer, log: true, args: minterDeployArgs });
    const minterContract = await deployments.get('Minter');
    await (await tapOFTContract.setMinter(minterContract.address)).wait(); //set Minter on TapOFT

    //deploy FeeDistributor
    console.log('   Deploying FeeDistributor...');
    const latestBlock = await ethers.provider.getBlock('latest');
    const feeDistributorArgs = [veTapContract.address, latestBlock.timestamp, tapOFTDeployment.address, deployer, deployer];
    await deploy('FeeDistributor', { from: deployer, log: true, args: feeDistributorArgs });
    const feeDistributorContract = await deployments.get('FeeDistributor');

    console.log('   Verifying Contracts...');
    console.log('   Verifying VeTap...');
    try {
        await hre.run('verify', {
            address: veTapContract.address,
            constructorArgsParams: veTapDeployArgs,
        });
    } catch (err) {
        console.log(err);
    }

    console.log('   Verifying GaugeController...');
    try {
        await hre.run('verify', {
            address: gaugeControllerContract.address,
            constructorArgsParams: gaugeContollerDeployArgs,
        });
    } catch (err) {
        console.log(err);
    }

    console.log('   Verifying Minter...');
    try {
        await hre.run('verify', {
            address: minterContract.address,
            constructorArgsParams: minterDeployArgs,
        });
    } catch (err) {
        console.log(err);
    }

    console.log('   Verifying FeeDistributor...');
    try {
        await hre.run('verify', {
            address: feeDistributorContract.address,
            constructorArgsParams: feeDistributorArgs,
        });
    } catch (err) {
        console.log(err);
    }
};

export default func;
func.tags = ['Governance'];
