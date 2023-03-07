import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract, TProjectCaller } from 'tapioca-sdk/dist/shared';

export const getDeployments = async (
    hre: HardhatRuntimeEnvironment,
    local?: boolean,
    repo?: TProjectCaller,
): Promise<TContract[]> => {
    return (
        SDK.API.utils.getDeployments(
            repo ?? 'Tap-Token',
            await hre.getChainId(),
            Boolean(local),
        ) ?? []
    );
};
export const getLocalDeployments__task = async function (
    taskArgs: { contractName?: string },
    hre: HardhatRuntimeEnvironment,
) {
    try {
        if (taskArgs.contractName) {
            console.log(
                await SDK.API.utils.getDeployment(
                    'Tap-Token',
                    taskArgs.contractName,
                    await hre.getChainId(),
                ),
            );
        } else {
            console.log(await getDeployments(hre, true));
        }
    } catch (e) {
        console.log(
            '[-] No local deployments found on chain id',
            await hre.getChainId(),
        );
    }
};

export const getSDKDeployments__task = async function (
    taskArgs: { repo: TProjectCaller; contractName?: string },
    hre: HardhatRuntimeEnvironment,
) {
    try {
        if (taskArgs.contractName) {
            console.log(
                await SDK.API.utils.getDeployment(
                    taskArgs.repo,
                    taskArgs.contractName,
                    await hre.getChainId(),
                ),
            );
        } else {
            console.log(await getDeployments(hre, false, taskArgs.repo));
        }
    } catch (e) {
        console.log(
            '[-] No SDK deployments found on chain id',
            await hre.getChainId(),
        );
    }
};
