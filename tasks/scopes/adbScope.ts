import { scope } from 'hardhat/config';
import { setTapOracle__task } from 'tasks/exec/adb/07-ab-setTapOracle';
import { setPhase2MerkleRoots__task } from 'tasks/exec/adb/08-ab-setPhase2MerkleRoots';
import { registerUserForPhase__task } from 'tasks/exec/adb/09-ab-registerUserForPhase';
import { setPaymentTokenOnAB__task } from 'tasks/exec/adb/10-ab-setPaymentToken';
import { setPaymentTokenBeneficiaryAB__task } from 'tasks/exec/adb/11-ab-setPaymentTokenBeneficiary';
import { collectPaymentTokensOnAB__task } from 'tasks/exec/adb/12-ab-collectPaymentTokens';
import { daoRecoverTAPFromAB__task } from 'tasks/exec/adb/13-ab-daoRecoverTAP';

const adbScope = scope('adb', 'AirdropBroker setter tasks');

adbScope.task(
    'setTapOracleOnAB',
    'Sets TapOracle address on AirdropBroker',
    setTapOracle__task,
);

adbScope.task(
    'setPhase2MerkleRoots',
    'Sets phase 2 merkle roots on AirdropBroker',
    setPhase2MerkleRoots__task,
);

adbScope.task(
    'registerUserForPhase',
    'Register user on AirdropBroker',
    registerUserForPhase__task,
);

adbScope.task(
    'setPaymentTokenOnAB',
    'Set payment token on AirdropBroker',
    setPaymentTokenOnAB__task,
);

adbScope.task(
    'setPaymentTokenBeneficiaryOnAB',
    'Set payment token beneficiary on AirdropBroker',
    setPaymentTokenBeneficiaryAB__task,
);

adbScope.task(
    'collectPaymentTokensOnAB',
    'Collect payment tokens from AirdropBroker',
    collectPaymentTokensOnAB__task,
);

adbScope.task(
    'daoRecoverTAPFromAB',
    'Initiates a dao recover action on AirdropBroker',
    daoRecoverTAPFromAB__task,
);
