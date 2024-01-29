import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import { deployStack__task } from '../deploy/3-deployStack';
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
