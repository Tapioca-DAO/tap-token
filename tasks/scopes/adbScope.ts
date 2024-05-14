import { scope } from 'hardhat/config';
import { TAP_TASK } from 'tapioca-sdk';
import { setTapOracle__task } from 'tasks/exec/adb/07-ab-setTapOracle';
import { setPhase2MerkleRoots__task } from 'tasks/exec/adb/08-ab-setPhase2MerkleRoots';
import { registerUserForPhase__task } from 'tasks/exec/adb/09-ab-registerUserForPhase';
import { setPaymentTokenOnAB__task } from 'tasks/exec/adb/10-ab-setPaymentToken';
import { setPaymentTokenBeneficiaryAB__task } from 'tasks/exec/adb/11-ab-setPaymentTokenBeneficiary';
import { collectPaymentTokensOnAB__task } from 'tasks/exec/adb/12-ab-collectPaymentTokens';
import { daoRecoverTAPFromAB__task } from 'tasks/exec/adb/13-ab-daoRecoverTAP';
import { adb_addPaymentToken__task } from 'tasks/exec/adb/adb_addPaymentToken';
import { adb_newEpoch__task } from 'tasks/exec/adb/adb_newEpoch';
import { adb_setPhase2Roots__task } from 'tasks/exec/adb/adb_registerUserForPhase';

const adbScope = scope('adb', 'AirdropBroker setter tasks');

TAP_TASK(
    adbScope
        .task(
            'registerUserForPhase',
            'Register users for phase 1 or 4 on AirdropBroker. A JSON file with users and amounts is required.',
            adb_setPhase2Roots__task,
        )
        .addParam('phase', 'Phase number')
        .addParam('userFile', 'Path to the JSON file with users and amounts'),
);

TAP_TASK(
    adbScope
        .task(
            'addPaymentToken',
            'Add a payment token to AirdropBroker. Requires the token address and the oracle address.',
            adb_addPaymentToken__task,
        )
        .addParam('paymentToken', 'Address of the payment token')
        .addParam('oracle', 'Address of the oracle contract'),
);

TAP_TASK(
    adbScope.task(
        'newEpoch',
        'Starts a new epoch on AirdropBroker',
        adb_newEpoch__task,
    ),
);

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
    'registerUserForPhase__deprecated',
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
