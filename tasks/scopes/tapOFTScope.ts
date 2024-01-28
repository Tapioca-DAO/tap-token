import { scope, task } from 'hardhat/config';
import { rescueEthOnTap__task } from 'tasks/exec/tap/24-tap-rescueEth';
import { setTwTapOnTap__task } from 'tasks/exec/tap/25-tap-setTwTap';
import { setGovernanceChainIdentifierOnTap__task } from 'tasks/exec/tap/26-tap-setGovernanceChainIdentifier';
import { updatePauseOnTap__task } from 'tasks/exec/tap/27-tap-updatePause';
import { setMinterOnTap__task } from 'tasks/exec/tap/28-tap-setMinter';
import { sendTokens__task } from 'tasks/exec/sendTokens';
import { setOFTPeers__task } from 'tasks/exec/setOFTPeers';
import { setOracleMockRate__task } from 'tasks/exec/setterTasks';

const tapOFTScope = scope('tapoft', 'TapOFT setter tasks');

task(
    'setOracleMockRate',
    'Set exchange rate for a mock oracle',
    setOracleMockRate__task,
)
    .addParam('oracleAddress', 'Address of the oracle')
    .addParam('rate', 'Exchange rate');

// --- TapOFT
tapOFTScope.task(
    'rescueEthOnTap',
    'Rescue ETH on TapOFT',
    rescueEthOnTap__task,
);
tapOFTScope.task('setTwTapOnTap', 'Set twTap on TapOFT', setTwTapOnTap__task);
tapOFTScope.task(
    'setGovernanceChainIdentifierOnTap',
    'Set Governance chain identifier on TapOFT',
    setGovernanceChainIdentifierOnTap__task,
);
tapOFTScope.task(
    'updatePauseOnTap',
    'Toggle pause on TapOFT',
    updatePauseOnTap__task,
);
tapOFTScope.task(
    'setMinterOnTap',
    'Set minter on TapOFT',
    setMinterOnTap__task,
);

tapOFTScope
    .task('setOFTPeers', 'Set OFT peers', setOFTPeers__task)
    .addParam(
        'target',
        'Name of the target contract, as deployed in local__db.',
    );

tapOFTScope
    .task('sendTokens', 'Set OFT tokens', sendTokens__task)
    .addParam(
        'target',
        'Name of the target contract, as deployed in local__db.',
    )
    .addParam('dst', 'Name of the destination chain. As in hardhat.config.ts');
