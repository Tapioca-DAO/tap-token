import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    //all of these should be constants
    const lzEndpoint = '';
    const teamAddress = '';
    const advisorsAddress = '';
    const globalIncentivesAddress = '';
    const initialDexLiquidityAddress = '';
    const seedAddress = '';
    const privateAddress = '';
    const idoAddress = '';
    const airdropAddress = '';

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
    ];
    await deploy('TapOFT', {
        from: deployer,
        log: true,
        args,
    });

    if (hre.network.tags['optimism']) {
        try {
            const contract = await deployments.get('TapOFT');
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
func.tags = ['TapOFT'];
