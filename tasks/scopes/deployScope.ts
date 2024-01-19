import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import {
    deployOracleMock__task,
    deployVesting__task,
} from '../deploy/contractDeployment';
import { deployStack__task } from '../deploy/deployStack';
import { deployTapOFTv2__task } from '../deploy/deployTapOFTv2';

const deployScope = scope('Deploy', 'Deployment tasks');

deployScope
    .task(
        'deployStack',
        'Deploys the entire stack with on deterministic addresses, with MulticallV3.',
        deployStack__task,
    )
    .addFlag('load', 'Load the contracts from the local database.');

deployScope.task(
    'deployTapOFTv2',
    'Deploys just the TapOFT contract',
    deployTapOFTv2__task,
);

deployScope
    .task(
        'deployVesting',
        'Deploys a new Vesting contract',
        deployVesting__task,
    )
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('token', 'Vested token')
    .addParam('cliff', 'Cliff duration in seconds')
    .addParam('duration', 'Vesting duration in seconds');

deployScope
    .task(
        'deployOracleMock',
        'Deploys a new Oracle mock contract',
        deployOracleMock__task,
    )
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('erc20Name', 'Initial amount of tokens')
    .addParam('rate', 'Exchange rate, 1e18 dec');
