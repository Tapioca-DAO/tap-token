import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildLTap } from 'tasks/deployBuilds/preLbpStack/buildLTap';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';

export const deployPreLbpStack__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        tapiocaDeployTask,
    );
};

async function tapiocaDeployTask(params: TTapiocaDeployerVmPass<object>) {
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    // Set a fake LBP address if testnet
    if (isTestnet) {
        const lbpReceiver = hre.ethers.Wallet.fromMnemonic(
            'radar blur cabbage chef fix engine embark joy scheme fiction master release',
        );
        // Perform a fake save globally to store the Mocks
        hre.SDK.db.saveGlobally(
            {
                [hre.SDK.eChainId]: {
                    name: hre.network.name,
                    lastBlockHeight: await hre.ethers.provider.getBlockNumber(),
                    contracts: [
                        {
                            name: 'TAPIOCA_LBP',
                            address: lbpReceiver.address,
                            meta: {
                                mock: true,
                                desc: 'Mock contract deployed from tap-token',
                            },
                        },
                    ],
                },
            },
            TAPIOCA_PROJECTS_NAME.TapiocaBar,
            tag,
        );
    }

    const lbpDep = hre.SDK.db.findGlobalDeployment(
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.eChainId,
        'TAPIOCA_LBP', // TODO replace by find global deployment?],
        tag,
    );
    if (!lbpDep) {
        throw '[-] LBP not found';
    }

    VM.add(await buildLTap(hre, DEPLOYMENT_NAMES.LTAP, [lbpDep.address], []));
}
