import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import { deployFinalStack__task } from '../deploy/3-deployFinalStack';
import { deployPreLbpStack__task } from 'tasks/deploy/1-deployPreLbpStack';
import { deployPostLbpStack__task } from 'tasks/deploy/2-deployPostLbpStack';

const deployScope = scope('deploys', 'Deployment tasks');

deployScope
    .task(
        'preLbp',
        'Deploy the Pre LBP stack of the tap-token repo. Includes the LTAP.',
        deployPreLbpStack__task,
    )
    .addOptionalParam(
        'tag',
        'The tag to use for the deployment. Defaults to "default" if not specified.',
        'default',
    )
    .addFlag(
        'load',
        'Load the contracts from the database instead of building them.',
    )
    .addFlag('verify', 'Add to verify the contracts after deployment.');

deployScope
    .task(
        'postLbp',
        'Deploy and init the Post LBP stack of the tap-token repo. Includes AOTAP, ADB, Vesting, TapToken.',
        deployPostLbpStack__task,
    )
    .addOptionalParam(
        'tag',
        'The tag to use for the deployment. Defaults to "default" if not specified.',
        'default',
    )
    .addFlag(
        'load',
        'Load the contracts from the database instead of building them.',
    )
    .addFlag('verify', 'Add to verify the contracts after deployment.');
deployScope
    .task(
        'final',
        'Deploy and init the final stack of the tap-token repo. Includes the TOB, TOLP, OTAP, TwTap.',
        deployFinalStack__task,
    )
    .addOptionalParam(
        'tag',
        'The tag to use for the deployment. Defaults to "default" if not specified.',
        'default',
    )
    .addFlag(
        'load',
        'Load the contracts from the database instead of building them.',
    )
    .addFlag('verify', 'Add to verify the contracts after deployment.');
