import { scope } from 'hardhat/config';
import { setRegisterSGLOnTOLP__task } from 'tasks/exec/tolp/19-tolp-setRegisterSGL';
import { setSglPoolWeightOnTOLP__task } from 'tasks/exec/tolp/20-tolp-setSglPoolWeight';
import { activateSglPoolRescueOnTOLP__task } from 'tasks/exec/tolp/21-tolp-activateSglPoolRescue';
import { unregisterSingularityOnTOLP__task } from 'tasks/exec/tolp/22-tolp-unregisterSingularity';
import {
    setTOLPRegisterSingularity__task,
    setTOLPUnregisterSingularity__task,
} from 'tasks/exec/setterTasks';

const tOLPScope = scope('tolp', 'TapiocaOptionLiquidityPool setter tasks');

tOLPScope
    .task(
        'setTOLPRegisterSingularity',
        'Register an SGL on tOLP ',
        setTOLPRegisterSingularity__task,
    )
    .addParam('sglAddress', 'Address of the SGL receipt token')
    .addParam('weight', 'Weight of the gauge')
    .addOptionalParam('tag', 'Tag of the deployment');

tOLPScope
    .task(
        'setTOLPUnregisterSingularity',
        'Unregister an SGL on tOLP ',
        setTOLPUnregisterSingularity__task,
    )
    .addParam('sglAddress', 'Address of the SGL receipt token');

tOLPScope.task(
    'setRegisterSGLOnTOLP',
    'Register an SGL on tOLP',
    setRegisterSGLOnTOLP__task,
);

tOLPScope.task(
    'setSglPoolWeightOnTOLP',
    'Sets a registered SGL weight',
    setSglPoolWeightOnTOLP__task,
);

tOLPScope.task(
    'activateSglPoolRescueOnTOLP',
    'Activates SGL pool rescue on tOLP',
    activateSglPoolRescueOnTOLP__task,
);

tOLPScope.task(
    'unregisterSingularityOnTOLP',
    'Unregisters SGL on tOLP',
    unregisterSingularityOnTOLP__task,
);
