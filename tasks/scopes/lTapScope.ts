import { scope } from 'hardhat/config';
import { setLockedUntilOnLtap__task } from 'tasks/exec/ltap/23-ltap-setLockedUntil';

const lTapScope = scope('ltap', 'LockedTap setter tasks');
// --- LTAP
lTapScope.task(
    'setLockedUntilOnLtap',
    'Set locked until on LTAP',
    setLockedUntilOnLtap__task,
);
