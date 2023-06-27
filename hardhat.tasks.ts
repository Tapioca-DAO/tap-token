import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import {
    deployOracleMock__task,
    deployVesting__task,
} from './tasks/deploy/contractDeployment';
import {
    setOracleMockRate__task,
    setTOBPaymentToken__task,
    setTOLPRegisterSingularity__task,
    setTOLPUnregisterSingularity__task,
} from './tasks/exec/setterTasks';

import { glob } from 'typechain';
import { configurePacketTypes__task } from './tasks/exec/configurePacketTypes';
import { deployStack__task } from './tasks/deploy/deployStack';
import { deployTapOFT__task } from './tasks/deploy/deployTapOFT';
import { setRegisterSGL__task } from './tasks/exec/setRegisterSGL';
import { setPaymentToken__task } from './tasks/exec/setPaymentToken';
import { setRegisterTapOracle__task } from './tasks/exec/setRegisterTapOracle';
import { testParticipateCrossChain__task } from './tasks/exec/tests/test-participateCrossChain';
import { testExitCrossChain__task } from './tasks/exec/tests/test-exitCrossChain';

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task(
    'getContractNames',
    'Get the names of all contracts deployed on the current chain ID.',
    async (taskArgs, hre) => {
        console.log(
            glob(process.cwd(), [
                `${hre.config.paths.artifacts}/**/!(*.dbg).json`,
            ]).map((e) => e.split('/').slice(-1)[0]),
        );
    },
);

task('deployVesting', 'Deploys a new Vesting contract', deployVesting__task)
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('token', 'Vested token')
    .addParam('cliff', 'Cliff duration in seconds')
    .addParam('duration', 'Vesting duration in seconds');

task(
    'deployOracleMock',
    'Deploys a new Oracle mock contract',
    deployOracleMock__task,
)
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('erc20Name', 'Initial amount of tokens')
    .addParam('rate', 'Exchange rate, 1e18 dec');

task(
    'setOracleMockRate',
    'Set exchange rate for a mock oracle',
    setOracleMockRate__task,
)
    .addParam('oracleAddress', 'Address of the oracle')
    .addParam('rate', 'Exchange rate');

task(
    'setTOBPaymentToken',
    'Set a payment token on tOB',
    setTOBPaymentToken__task,
)
    .addParam('tknAddress', 'Address of the payment token')
    .addParam('oracleAddress', 'Address of the oracle')
    .addParam('oracleData', 'Oracle data');

task(
    'setTOLPRegisterSingularity',
    'Register an SGL on tOLP ',
    setTOLPRegisterSingularity__task,
)
    .addParam('sglAddress', 'Address of the SGL receipt token')
    .addParam('weight', 'Weight of the gauge');

task(
    'setTOLPUnregisterSingularity',
    'Unregister an SGL on tOLP ',
    setTOLPUnregisterSingularity__task,
).addParam('sglAddress', 'Address of the SGL receipt token');

task(
    'configurePacketTypes',
    'Cofigures min destination gas and the usage of custom adapters',
    configurePacketTypes__task,
)
    .addParam('dstLzChainId', 'LZ destination chain id for trusted remotes')
    .addParam('src', 'TAP address');

task(
    'deployStack',
    'Deploys the entire stack with on deterministic addresses, with MulticallV3.',
    deployStack__task,
).addFlag('load', 'Load the contracts from the local database.');

task('deployTapOFT', 'Deploys just the TapOFT contract', deployTapOFT__task);

// ---- toLP
task('setRegisterSGL', 'Register an SGL on tOLP', setRegisterSGL__task);

// ---- tOB
task(
    'setRegisterTapOracle',
    'Register an oracle on tOB',
    setRegisterTapOracle__task,
);
task('setPaymentToken', 'Register an oracle on tOB', setPaymentToken__task);

// Tests
task(
    'testParticipateCrossChain',
    'Test a cross-chain participation in twTAP',
    testParticipateCrossChain__task,
);
task(
    'testExitCrossChain',
    'Test a cross-chain exit in twTAP',
    testExitCrossChain__task,
);
