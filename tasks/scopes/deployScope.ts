import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import { deployFinalStack__task } from '../deploy/3-deployFinalStack';
import { deployPreLbpStack__task } from 'tasks/deploy/1-deployPreLbpStack';
import { deployPostLbpStack__task } from 'tasks/deploy/2-deployPostLbpStack';
import { TAP_TASK } from 'tapioca-sdk';

const deployScope = scope('deploys', 'Deployment tasks');

TAP_TASK(
    deployScope.task(
        'preLbp',
        'Deploy the Pre LBP stack of the tap-token repo. Includes the LTAP.',
        deployPreLbpStack__task,
    ),
);

TAP_TASK(
    deployScope.task(
        'postLbp',
        'Deploy and init the Post LBP stack of the tap-token repo. Includes AOTAP, ADB, Vesting, TapToken.',
        deployPostLbpStack__task,
    ),
);

TAP_TASK(
    deployScope.task(
        'final',
        'Deploy and init the final stack of the tap-token repo. Includes the TOB, TOLP, OTAP, TwTap.',
        deployFinalStack__task,
    ),
);
