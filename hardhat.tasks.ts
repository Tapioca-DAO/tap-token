import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { exportSDK__task } from './tasks/exportSDK';
import { setTrustedRemote__task } from './tasks/setTrustedRemote';
import { deployERC20Mock__task, deployVesting__task } from './tasks/contractDeployment';
import { setOracleMockRate__task } from './tasks/setterTasks';

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task('exportSDK', 'Generate and export the typings and/or addresses for the SDK. May deploy contracts.', exportSDK__task).addFlag(
    'mainnet',
    'Using the current chain ID deployments.',
);

task('setTrustedRemote', 'Calls setTrustedRemote on TapOFT contract', setTrustedRemote__task)
    .addParam('chain', 'LZ destination chain id for trusted remotes')
    .addParam('dst', 'TapOFT destination address')
    .addParam('src', 'TapOFT source address');

task('deployVesting', 'Deploys a new Vesting contract', deployVesting__task)
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('token', 'Vested token')
    .addParam('cliff', 'Cliff duration in seconds')
    .addParam('duration', 'Vesting duration in seconds');

task('deployERC20Mock', 'Deploys a new Vesting contract', deployERC20Mock__task)
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('initialAmount', 'Initial amount of tokens')
    .addParam('decimals', 'Number of decimals');

task('setOracleMockRate', 'Set exchange rate for a mock oracle', setOracleMockRate__task)
    .addParam('oracleAddress', 'Address of the oracle')
    .addParam('rate', 'Exchange rate');
