import { TapiocaMulticall } from '@tapioca-sdk/typechain/tapioca-periphery';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';
import { buildERC20Mock } from 'tasks/deployBuilds/mocks/buildMockERC20';
import { buildOracleMock } from 'tasks/deployBuilds/mocks/buildOracleMock';
import { loadVM } from 'tasks/utils';

export const executeTestnetPostLbpStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
) => {
    const VM = await loadVM(hre, tag);
    const multicall = await VM.getMulticall();

    VM.add(
        await buildERC20Mock(hre, 'MOCK_USDC', [
            'MOCK_USDC',
            'MOCK_USDC',
            (1e18).toString(),
            6,
            multicall.address,
        ]),
    )
        .add(
            await buildOracleMock(hre, DEPLOYMENT_NAMES.USDC_SEER_CL_ORACLE, [
                'MOCK_USDC_ORACLE',
                'MOCK_USDC_ORACLE',
                1e18, // 1 USDC = 1 USD
            ]),
        )
        .add(
            await buildOracleMock(hre, DEPLOYMENT_NAMES.TAP_ORACLE, [
                'MOCK_TAP_ORACLE',
                'MOCK_TAP_ORACLE',
                33e17, // 1 TAP = 3.3 USD
            ]),
        );

    await VM.execute(3);
    await VM.save();
    await VM.verify();

    /**
     * Load contracts
     */
    const { mockUsdc } = await loadContract(hre, tag);

    DEPLOY_CONFIG.MISC[hre.SDK.eChainId]!.USDC = mockUsdc.address; // Inject newly created Mock USDC address
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const mockUsdc = getContract(hre, tag, 'MOCK_USDC');

    return {
        mockUsdc,
    };
}

function getContract(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    contractName: string,
) {
    const contract = hre.SDK.db.findLocalDeployment(
        hre.SDK.eChainId,
        contractName,
        tag,
    )!;
    if (!contract) {
        throw new Error(
            `[-] ${contractName} not found on chain ${hre.network.name} tag ${tag}`,
        );
    }
    return contract;
}
