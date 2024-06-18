import { scope } from 'hardhat/config';
import { TAP_TASK } from 'tapioca-sdk';
import { sandbox__task } from 'tasks/exec/misc/sandbox';

const miscScope = scope('misc', ' Miscellaneous tasks');

// Sandbox
TAP_TASK(miscScope.task('sandbox', 'Sandbox', sandbox__task));
