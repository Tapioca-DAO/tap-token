import { scope } from 'hardhat/config';
import { TAP_TASK } from 'tapioca-sdk';
import { registerUsersVesting__task } from 'tasks/exec/vesting/registerUsersVesting';
import { vestingInit__task } from 'tasks/exec/vesting/vestingInit';

const vestingScope = scope('vesting', 'Vesting setter tasks');

TAP_TASK(
    vestingScope
        .task(
            'registerVestingUsers',
            'Add users for a given vesting',
            registerUsersVesting__task,
        )
        .addParam('contributorAddress', 'Address of the contributor multisig')
        .addParam('seedFile', 'Path to the seed file')
        .addParam('preSeedFile', 'Path to the pre-seed file'),
);

TAP_TASK(
    vestingScope.task('initVesting', 'Inits user vesting', vestingInit__task),
);
