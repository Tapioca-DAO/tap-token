import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { buildLTap } from 'tasks/deployBuilds/preLbpStack/buildLTap';
import { loadVM } from 'tasks/utils';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';
import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';

export const deployPreLbpStack__task = async (
    taskArgs: { tag?: string; load?: boolean; verify: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = taskArgs.tag ?? 'default';
    const VM = await loadVM(hre, tag);
    const chainInfo = hre.SDK.utils.getChainBy('chainId', hre.SDK.eChainId)!;

    // Set a fake LBP if testnet
    const isTestnet = chainInfo.tags.find((tag) => tag === 'testnet');
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

    if (taskArgs.load) {
        VM.load(
            hre.SDK.db.loadLocalDeployment(tag, hre.SDK.eChainId)?.contracts ??
                [],
        );
    } else {
        // Build contracts
        VM.add(
            await buildLTap(hre, DEPLOYMENT_NAMES.LTAP, [lbpDep.address], []),
        );
        // Add and execute
        await VM.execute();
        await VM.save();
    }

    if (taskArgs.verify) {
        await VM.verify();
    }

    console.log('[+] Pre LBP Stack deployed! 🎉');
};
