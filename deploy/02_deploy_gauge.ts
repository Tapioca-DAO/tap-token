import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    //deploy TimedGauge implementation reference
    const depositToken = '';
    const rewardToken = '';
    const gaugeDistributor = '';
    await deploy('TimedGauge', {
        from: deployer,
        log: true,
    });
    const gaugeContract = await deployments.get('TimedGauge');
    const timedGaugeContract = await ethers.getContractAt('TImedGauge', gaugeContract.address);
    await timedGaugeContract.init(depositToken, rewardToken, deployer, gaugeDistributor);

    if (hre.network.tags['optimism']) {
        try {
            await hre.run('verify', {
                address: gaugeContract.address,
            });
        } catch (err) {
            console.log(err);
        }
    }

    //deploy gauge factory
    const args = [gaugeContract.address];
    await deploy('GaugeFactory', {
        from: deployer,
        log: true,
        args,
    });
    const gaugeFactoryContract = await deployments.get('GaugeFactory');
    try {
        await hre.run('verify', {
            address: gaugeFactoryContract.address,
            constructorArgsParams: args,
        });
    } catch (err) {
        console.log(err);
    }
};

export default func;
func.tags = ['LiquidityGauge'];
