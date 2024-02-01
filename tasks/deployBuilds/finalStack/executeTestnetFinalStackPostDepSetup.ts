import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { TapiocaMulticall } from '@tapioca-sdk/typechain/tapioca-periphery';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';
import { buildERC20Mock } from 'tasks/deployBuilds/mocks/buildMockERC20';
import { buildOracleMock } from 'tasks/deployBuilds/mocks/buildOracleMock';
import { loadVM } from 'tasks/utils';

export const executeTestnetFinalStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
) => {
    const VM = await loadVM(hre, tag);
    const multicall = await VM.getMulticall();

    VM.add(
        await buildERC20Mock(hre, 'USDO', [
            'MOCK_USDO',
            'MOCK_USDO',
            (1e18).toString(),
            18,
            multicall.address,
        ]),
    )
        .add(
            await buildOracleMock(hre, 'USDO_SEER_UNI_ORACLE', [
                'MOCK_USDO_ORACLE',
                'MOCK_USDO_ORACLE',
                1e18, // 1 USDC = 1 USD
            ]),
        )
        .add(
            await buildERC20Mock(hre, 'ARB_SGL_GLP', [
                'MOCK_ARB_SGL_GLP',
                'MOCK_ARB_SGL_GLP',
                (1e18).toString(),
                18,
                multicall.address,
            ]),
        )
        .add(
            await buildERC20Mock(hre, 'TOFT_MAINNET_SGL_DAI', [
                'MOCK_TOFT_MAINNET_SGL_DAI',
                'MOCK_TOFT_MAINNET_SGL_DAI',
                (1e18).toString(),
                18,
                multicall.address,
            ]),
        );

    await VM.execute();
    await VM.verify();

    // Perform a fake save globally to store the Mocks
    hre.SDK.db.saveGlobally(
        {
            [hre.SDK.eChainId]: {
                name: hre.network.name,
                lastBlockHeight: await hre.ethers.provider.getBlockNumber(),
                contracts: VM.list().map((contract) => ({
                    ...contract,
                    meta: {
                        ...contract.meta,
                        mock: true,
                        description: 'Mock contract deployed from tap-token',
                    },
                })),
            },
        },
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        tag,
    );

    const { mockUsdc, mockArbSglGlp, mockToftMainnetSglDai } =
        await loadContract(hre, tag);
    DEPLOY_CONFIG.MISC[hre.SDK.eChainId]!.USDC = mockUsdc.address; // Inject previously created Mock USDC address (from postLbpStack)

    // Mint both SGL to perform a YB deposit in the subsequent Deps
    const calls: TapiocaMulticall.CallStruct[] = [];
    calls.push({
        target: mockArbSglGlp.address,
        allowFailure: false,
        callData: mockArbSglGlp.interface.encodeFunctionData('freeMint', [
            (1e18).toString(),
        ]),
    });
    calls.push({
        target: mockToftMainnetSglDai.address,
        allowFailure: false,
        callData: mockArbSglGlp.interface.encodeFunctionData('freeMint', [
            (1e18).toString(),
        ]),
    });
    await VM.executeMulticall(calls);
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const mockUsdc = getContract(hre, tag, 'MOCK_USDC');
    const mockArbSglGlp = await hre.ethers.getContractAt(
        'ERC20Mock',
        getContract(hre, tag, 'ARB_SGL_GLP').address,
    );
    const mockToftMainnetSglDai = await hre.ethers.getContractAt(
        'ERC20Mock',
        getContract(hre, tag, 'TOFT_MAINNET_SGL_DAI').address,
    );

    return {
        mockUsdc,
        mockArbSglGlp,
        mockToftMainnetSglDai,
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
