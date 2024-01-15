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
import { setRegisterSGLOnTOLP__task } from './tasks/exec/19-tolp-setRegisterSGL';
import { setPaymentTokenOnTOB__task } from './tasks/exec/16-tob-setPaymentToken';
import { testParticipateCrossChain__task } from './tasks/exec/tests/test-participateCrossChain';
import { testExitCrossChain__task } from './tasks/exec/tests/test-exitCrossChain';
import { setTwTapRewardToken__task } from './tasks/exec/04-twTap-setTwTapRewardToken';
import { testClaimRewards__task } from './tasks/exec/tests/test-claimRewards';
import { setDistributeTwTapRewards__task } from './tasks/exec/05-twTap-setDistributeTwTapRewards';
import { setAdvanceWeek__task } from './tasks/exec/06-twTap-setAdvanceWeek';
import { deployMockADB__task } from './tasks/deployMock/deployMockADB';
import { registerUserForVesting__task } from './tasks/exec/01-vesting-registerUser';
import { initVesting__task } from './tasks/exec/02-vesting-init';
import { setMaxRewardTokensLength__task } from './tasks/exec/03-twTap-setMaxRewardTokensLength';
import { setTapOracle__task } from './tasks/exec/07-ab-setTapOracle';
import { setPhase2MerkleRoots__task } from './tasks/exec/08-ab-setPhase2MerkleRoots';
import { registerUserForPhase__task } from './tasks/exec/09-ab-registerUserForPhase';
import { setPaymentTokenOnAB__task } from './tasks/exec/10-ab-setPaymentToken';
import { setPaymentTokenBeneficiaryAB__task } from './tasks/exec/11-ab-setPaymentTokenBeneficiary';
import { collectPaymentTokensOnAB__task } from './tasks/exec/12-ab-collectPaymentTokens';
import { daoRecoverTAPFromAB__task } from './tasks/exec/13-ab-daoRecoverTAP';
import { setMinWeightFactorOnTOB__task } from './tasks/exec/14-tob-setMinWeightFactor';
import { setTapOracleOnTOB__task } from './tasks/exec/15-tob-setTapOracle';
import { setPaymentTokenBeneficiaryOnTOB__task } from './tasks/exec/17-tob-setPaymentTokenBeneficiary';
import { collectPaymentTokensOnTOB__task } from './tasks/exec/18-tob-collectPaymentTokens';
import { setSglPoolWeightOnTOLP__task } from './tasks/exec/20-tolp-setSglPoolWeight';
import { activateSglPoolRescueOnTOLP__task } from './tasks/exec/21-tolp-activateSglPoolRescue';
import { unregisterSingularityOnTOLP__task } from './tasks/exec/22-tolp-unregisterSingularity';
import { setLockedUntilOnLtap__task } from './tasks/exec/23-ltap-setLockedUntil';
import { rescueEthOnTap__task } from './tasks/exec/24-tap-rescueEth';
import { setTwTapOnTap__task } from './tasks/exec/25-tap-setTwTap';
import { setGovernanceChainIdentifierOnTap__task } from './tasks/exec/26-tap-setGovernanceChainIdentifier';
import { updatePauseOnTap__task } from './tasks/exec/27-tap-updatePause';
import { setMinterOnTap__task } from './tasks/exec/28-tap-setMinter';

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
    .addParam('erc20Name', 'Name of the ERC20 token')
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

// ---- twTAP
task(
    'setTwTapRewardToken',
    'Set the reward token for twTAP',
    setTwTapRewardToken__task,
);

task(
    'setMaxRewardTokensLength',
    'Set max reward array length',
    setMaxRewardTokensLength__task,
);

task(
    'setDistributeTwTapRewards',
    'Distribute rewards for twTAP',
    setDistributeTwTapRewards__task,
);
task('setAdvanceWeek', 'Advance by 1 week', setAdvanceWeek__task);

// ---- toLP
task(
    'setRegisterSGLOnTOLP',
    'Register an SGL on tOLP',
    setRegisterSGLOnTOLP__task,
);

task(
    'setSglPoolWeightOnTOLP',
    'Sets a registered SGL weight',
    setSglPoolWeightOnTOLP__task,
);

task(
    'activateSglPoolRescueOnTOLP',
    'Activates SGL pool rescue on tOLP',
    activateSglPoolRescueOnTOLP__task,
);

task(
    'unregisterSingularityOnTOLP',
    'Unregisters SGL on tOLP',
    unregisterSingularityOnTOLP__task,
);
// ---- tOB
task(
    'setPaymentTokenOnTOB',
    'Register an oracle on tOB',
    setPaymentTokenOnTOB__task,
);

task(
    'registerUserForVesting',
    'Add vesting for user',
    registerUserForVesting__task,
);

task('initVesting', 'Inits user vesting', initVesting__task);

task(
    'setMinWeightFactorOnTOB',
    'Sets the minimum weight factor',
    setMinWeightFactorOnTOB__task,
);

task(
    'setTapOracleOnTOB',
    'Sets the Tap oracle on tOB',
    setTapOracleOnTOB__task,
);

task(
    'setPaymentTokenBeneficiaryOnTOB',
    'Sets the payment token beneficiary on tOB',
    setPaymentTokenBeneficiaryOnTOB__task,
);

task(
    'collectPaymentTokensOnTOB',
    'Collects payment tokens from tOB',
    collectPaymentTokensOnTOB__task,
);

// --- AB
task(
    'setTapOracleOnAB',
    'Sets TapOracle address on AirdropBroker',
    setTapOracle__task,
);

task(
    'setPhase2MerkleRoots',
    'Sets phase 2 merkle roots on AirdropBroker',
    setPhase2MerkleRoots__task,
);

task(
    'registerUserForPhase',
    'Register user on AirdropBroker',
    registerUserForPhase__task,
);

task(
    'setPaymentTokenOnAB',
    'Set payment token on AirdropBroker',
    setPaymentTokenOnAB__task,
);

task(
    'setPaymentTokenBeneficiaryOnAB',
    'Set payment token beneficiary on AirdropBroker',
    setPaymentTokenBeneficiaryAB__task,
);

task(
    'collectPaymentTokensOnAB',
    'Collect payment tokens from AirdropBroker',
    collectPaymentTokensOnAB__task,
);

task(
    'daoRecoverTAPFromAB',
    'Initiates a dao recover action on AirdropBroker',
    daoRecoverTAPFromAB__task,
);

// --- LTAP
task(
    'setLockedUntilOnLtap',
    'Set locked until on LTAP',
    setLockedUntilOnLtap__task,
);

// --- TapOFT
task('rescueEthOnTap', 'Rescue ETH on TapOFT', rescueEthOnTap__task);
task('setTwTapOnTap', 'Set twTap on TapOFT', setTwTapOnTap__task);
task(
    'setGovernanceChainIdentifierOnTap',
    'Set Governance chain identifier on TapOFT',
    setGovernanceChainIdentifierOnTap__task,
);
task('updatePauseOnTap', 'Toggle pause on TapOFT', updatePauseOnTap__task);
task('setMinterOnTap', 'Set minter on TapOFT', setMinterOnTap__task);

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
task(
    'testClaimRewards',
    'Test a cross-chain reward claim in twTAP',
    testClaimRewards__task,
);
task('deployMockADB', 'Deploy a mock ADB environment', deployMockADB__task);
