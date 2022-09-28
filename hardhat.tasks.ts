import { task } from 'hardhat/config';
import '@nomiclabs/hardhat-ethers';
import { exportSDK__task } from './tasks/exportSDK';
import { getGaugesInfo__task } from './tasks/getGaugesInfo';

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

task('getGaugesInfo', 'Returns gauge details', getGaugesInfo__task)
    .addParam('user', 'User address')
    .addOptionalParam('gauge', 'Gauge address');
