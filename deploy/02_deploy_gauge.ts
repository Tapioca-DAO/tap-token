import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import fs from 'fs';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const receiptAddress = '';
    const minterAddress = '';
    const args = [receiptAddress, minterAddress];
    await deploy('LiquidityGauge', {
        from: deployer,
        log: true,
        args,
    });

    if (hre.network.tags['optimism']) {
        try {
            const contract = await deployments.get('LiquidityGauge');
            await hre.run('verify', {
                address: contract.address,
                constructorArgsParams: args,
            });
        } catch (err) {
            console.log(err);
        }
    }
};

export default func;
func.tags = ['LiquidityGauge'];
