import { scope } from 'hardhat/config';
import { registerUserForVesting__task } from 'tasks/exec/01-vesting-registerUser';
import { initVesting__task } from 'tasks/exec/02-vesting-init';

const vestingScope = scope('vesting', 'Vesting setter tasks');

vestingScope.task(
    'registerUserForVesting',
    'Add vesting for user',
    registerUserForVesting__task,
);

vestingScope.task('initVesting', 'Inits user vesting', initVesting__task);
