import { scope } from 'hardhat/config';
import { testClaimRewards__task } from 'tasks/exec/tests/test-claimRewards';
import { testExitCrossChain__task } from 'tasks/exec/tests/test-exitCrossChain';
import { testParticipateCrossChain__task } from 'tasks/exec/tests/test-participateCrossChain';

const testnetScope = scope('testnet', 'Testnet setter tasks');

testnetScope.task(
    'testParticipateCrossChain',
    'Test a cross-chain participation in twTAP',
    testParticipateCrossChain__task,
);
testnetScope.task(
    'testExitCrossChain',
    'Test a cross-chain exit in twTAP',
    testExitCrossChain__task,
);
testnetScope.task(
    'testClaimRewards',
    'Test a cross-chain reward claim in twTAP',
    testClaimRewards__task,
);
