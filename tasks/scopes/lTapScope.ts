import { scope } from 'hardhat/config';
import { TAP_TASK } from 'tapioca-sdk';
import { setLockedUntilOnLtap__task } from 'tasks/exec/ltap/23-ltap-setLockedUntil';
import { ltap_openRedemptions__task } from 'tasks/exec/ltap/ltap_openRedemptions';

const lTapScope = scope('ltap', 'LockedTap setter tasks');

TAP_TASK(
    lTapScope.task(
        'openRedemptions',
        'Open redemptions on LTAP.',
        ltap_openRedemptions__task,
    ),
);

// --- LTAP
lTapScope.task(
    'setLockedUntilOnLtap',
    'Set locked until on LTAP',
    setLockedUntilOnLtap__task,
);
