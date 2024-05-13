import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';

export const ltap_openRedemptions__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        // eslint-disable-next-line @typescript-eslint/no-empty-function
        async () => {},
        tapiocaTask,
    );
};

async function tapiocaTask(params: TTapiocaDeployerVmPass<object>) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag } = taskArgs;

    const ltap = await hre.ethers.getContractAt(
        'LTap',
        loadLocalContract(hre, chainInfo.chainId, DEPLOYMENT_NAMES.LTAP, tag)
            .address,
    );
    const tapToken = loadLocalContract(
        hre,
        chainInfo.chainId,
        DEPLOYMENT_NAMES.TAP_TOKEN,
        tag,
    );

    await VM.executeMulticall([
        {
            target: ltap.address,
            allowFailure: false,
            callData: ltap.interface.encodeFunctionData('setTapToken', [
                tapToken.address,
            ]),
        },
        {
            target: ltap.address,
            allowFailure: false,
            callData: ltap.interface.encodeFunctionData('setOpenRedemption'),
        },
    ]);
}
