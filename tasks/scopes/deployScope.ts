import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import {
    deployOracleMock__task,
    deployVesting__task,
} from '../deploy/contractDeployment';
import { deployStack__task } from '../deploy/deployStack';
import { deployTapToken__task } from '../deploy/testnet/deployTapToken';

const deployScope = scope('deploys', 'Deployment tasks');

deployScope
    .task(
        'stack',
        'Deploys the entire stack with on deterministic addresses, with MulticallV3.',
        deployStack__task,
    )
    .addFlag('txPrice', 'Display the price of the Txs to execute.')
    .addFlag(
        'load',
        'Load the contracts from the local database. Used to execute afterDepSetup on previous deployment. Might not work if afterDepSetup was called on those',
    );

deployScope.task(
    'tapOft',
    'Deploys just the TapOFT contract',
    deployTapToken__task,
);

deployScope
    .task('vesting', 'Deploys a new Vesting contract', deployVesting__task)
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('token', 'Vested token')
    .addParam('cliff', 'Cliff duration in seconds')
    .addParam('duration', 'Vesting duration in seconds');

deployScope
    .task(
        'oracleMock',
        'Deploys a new Oracle mock contract',
        deployOracleMock__task,
    )
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('erc20Name', 'Initial amount of tokens')
    .addParam('rate', 'Exchange rate, 1e18 dec');
