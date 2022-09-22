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

    const tapContract = await deployments.get('TapOFT');
    const esTapContract = await deployments.get('esTapOFT');

    const args = [tapContract.address, esTapContract.address];
    await deploy('esTapVesting', {
        from: deployer,
        log: true,
        args,
    });

    const esTapVestingDeployment = await deployments.get('esTapVesting');

    const esTapOFT = await ethers.getContractAt('esTapOFT', esTapContract.address);
    await (await esTapOFT.setBurner(esTapVestingDeployment.address)).wait(); //set Minter on TapOFT

    try {
        await hre.run('verify', {
            address: esTapVestingDeployment.address,
            constructorArgsParams: args,
        });
    } catch (err: any) {
        console.log(`Error: ${err.message}\n`);
    }
};

export default func;
func.tags = ['esTapVesting'];
