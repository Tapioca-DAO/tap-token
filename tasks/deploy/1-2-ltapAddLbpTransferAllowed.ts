import * as TAPIOCA_PERIPH_CONFIG from '@tapioca-periph/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadGlobalContract, loadLocalContract } from 'tapioca-sdk';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';
import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';

/**
 * @notice Called after periph perLbp task
 *
 * Deploys: Arb
 * - LTAP
 */
export const deployLbp__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & {
        vault: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        // eslint-disable-next-line @typescript-eslint/no-empty-function
        async () => {},
        postDeploy,
    );
};

async function postDeploy(params: TTapiocaDeployerVmPass<object>) {
    const {
        hre,
        VM,
        tapiocaMulticallAddr,
        taskArgs,
        isTestnet,
        isHostChain,
        isSideChain,
    } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    const ltap = await hre.ethers.getContractAt(
        'LTap',
        loadLocalContract(
            hre,
            hre.SDK.chainInfo.chainId,
            DEPLOYMENT_NAMES.LTAP,
            tag,
        ).address,
    );

    const vault = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.chainInfo.chainId,
        TAPIOCA_PERIPH_CONFIG.DEPLOYMENT_NAMES.LBP_VAULT,
        tag,
    ).address;

    console.log('[+] Adding vault to LTAP transfer allow list');
    await VM.executeMulticall([
        {
            target: ltap.address,
            callData: ltap.interface.encodeFunctionData(
                'setTransferAllowList',
                [vault, true],
            ),
            allowFailure: false,
        },
    ]);
}
