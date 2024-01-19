import { scope } from 'hardhat/config';
import { setMinWeightFactorOnTOB__task } from 'tasks/exec/14-tob-setMinWeightFactor';
import { setTapOracleOnTOB__task } from 'tasks/exec/15-tob-setTapOracle';
import { setPaymentTokenOnTOB__task } from 'tasks/exec/16-tob-setPaymentToken';
import { setPaymentTokenBeneficiaryOnTOB__task } from 'tasks/exec/17-tob-setPaymentTokenBeneficiary';
import { collectPaymentTokensOnTOB__task } from 'tasks/exec/18-tob-collectPaymentTokens';
import { setTOBPaymentToken__task } from 'tasks/exec/setterTasks';

const tOBScope = scope('tob', 'TapiocaOptionBroker setter tasks');

tOBScope
    .task(
        'setTOBPaymentToken',
        'Set a payment token on tOB',
        setTOBPaymentToken__task,
    )
    .addParam('tknAddress', 'Address of the payment token')
    .addParam('oracleAddress', 'Address of the oracle')
    .addParam('oracleData', 'Oracle data');

tOBScope.task(
    'setPaymentTokenOnTOB',
    'Register an oracle on tOB',
    setPaymentTokenOnTOB__task,
);

tOBScope.task(
    'setMinWeightFactorOnTOB',
    'Sets the minimum weight factor',
    setMinWeightFactorOnTOB__task,
);

tOBScope.task(
    'setTapOracleOnTOB',
    'Sets the Tap oracle on tOB',
    setTapOracleOnTOB__task,
);

tOBScope.task(
    'setPaymentTokenBeneficiaryOnTOB',
    'Sets the payment token beneficiary on tOB',
    setPaymentTokenBeneficiaryOnTOB__task,
);

tOBScope.task(
    'collectPaymentTokensOnTOB',
    'Collects payment tokens from tOB',
    collectPaymentTokensOnTOB__task,
);
