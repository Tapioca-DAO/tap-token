import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { exportSDK__task } from './tasks/exportSDK';
import { setTrustedRemote__task } from './tasks/setTrustedRemote';

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
