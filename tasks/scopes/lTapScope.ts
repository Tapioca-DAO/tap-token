import { scope } from 'hardhat/config';
import { TAP_TASK } from 'tapioca-sdk';
import { setLockedUntilOnLtap__task } from 'tasks/exec/ltap/23-ltap-setLockedUntil';
import { ltap__deployMock__task } from 'tasks/exec/ltap/ltap_deployMock';
import { ltap_mintLtapMock__task } from 'tasks/exec/ltap/ltap_mintLtapMock';
import { ltap_openRedemptions__task } from 'tasks/exec/ltap/ltap_openRedemptions';

const lTapScope = scope('ltap', 'LockedTap setter tasks');

TAP_TASK(
    lTapScope.task(
        'openRedemptions',
        'Open redemptions on LTAP.',
        ltap_openRedemptions__task,
    ),
);

// TESTNET
TAP_TASK(
    lTapScope.task(
        'deployMock',
        'Deploy a mock LTAP contract.',
        ltap__deployMock__task,
    ),
);
TAP_TASK(
    lTapScope
        .task(
            'mintMock',
            'Mint LTAP tokens to an address.',
            ltap_mintLtapMock__task,
        )
        .addParam('userFile', 'Path to the JSON file with users and amounts'),
);

// --- LTAP
lTapScope.task(
    'setLockedUntilOnLtap',
    'Set locked until on LTAP',
    setLockedUntilOnLtap__task,
);
