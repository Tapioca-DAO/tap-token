import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import { deployFinalStack__task } from '../deploy/3-deployFinalStack';
import { deployPreLbpStack__task } from 'tasks/deploy/1-deployPreLbpStack';
import { TAP_TASK } from 'tapioca-sdk';
import { deployPostLbpStack_1__task } from 'tasks/deploy/2-1-deployPostLbpStack';
import { deployPostLbpStack_2__task } from 'tasks/deploy/2-2-deployPostLbpStack';
import { deploySideChainPostLbpStack_1__task } from 'tasks/deploy/2-1-sideChain-deployPostLbpStack';

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
        'postLbp1',
        'Deploy the Post LBP stack of the tap-token repo. Includes AOTAP, ADB, Vesting, TapToken. Call postLbp2 after this task.',
        deployPostLbpStack_1__task,
    ),
);
TAP_TASK(
    deployScope.task(
        'postLbp1-sideChain',
        'Deploy tap-token on side chain, different than the governance chain. Should be called after `postLbp1`.\n periph `preLbp` should be deployed on the said side chain',
        deploySideChainPostLbpStack_1__task,
    ),
);
TAP_TASK(
    deployScope.task(
        'postLbp2',
        'Setup the contracts of the Post LBP stack of the tap-token repo. Should be called after `postLbp1` and tapioca-periph `postLbp` tasks',
        deployPostLbpStack_2__task,
    ),
);

TAP_TASK(
    deployScope.task(
        'final',
        'Deploy and init the final stack of the tap-token repo. Includes the TOB, TOLP, OTAP, TwTap.',
        deployFinalStack__task,
    ),
);
