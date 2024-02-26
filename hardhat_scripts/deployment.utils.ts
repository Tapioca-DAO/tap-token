import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';

type TNetwork = ReturnType<
    typeof SDK.API.utils.getSupportedChains
>[number]['name'];

export const verify = async (
    hre: HardhatRuntimeEnvironment,
    address: string,
    args: any[],
) => {
    console.log(`[+] Verifying ${address}`);
    try {
        await hre.run('verify', {
            address: address,
            constructorArgsParams: args,
        });
        console.log('[+] Verified');
    } catch (err: any) {
        console.log(`[-] failed to verify ${address}; error: ${err.message}\n`);
    }
};

export const updateDeployments = async (
    contracts: TContract[],
    chainId: string,
    tag?: string,
) => {
    SDK.API.db.saveLocally(
        SDK.API.db.buildLocalDeployment({ chainId, contracts }),
        tag,
    );
};

export const registerContract = async (
    hre: HardhatRuntimeEnvironment,
    contractName: string,
    deploymentName: string,
    args: any[],
): Promise<TContract> => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log(`\n[+] Deploying ${contractName} as ${deploymentName}`);
    await deploy(deploymentName, {
        contract: contractName,
        from: deployer,
        log: true,
        args,
    });

    const contract = await deployments.get(deploymentName);
    console.log('[+] Deployed', contractName, 'at', contract.address);
    await verify(hre, contract.address, args);

    const deploymentMeta = {
        name: deploymentName,
        address: contract.address,
        meta: { constructorArguments: args },
    };
    await updateDeployments([deploymentMeta], await hre.getChainId());

    return deploymentMeta;
};
