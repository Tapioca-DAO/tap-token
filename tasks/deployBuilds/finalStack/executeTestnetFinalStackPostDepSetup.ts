import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { TapiocaMulticall } from '@tapioca-sdk/typechain/tapioca-periphery';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';
import { buildERC20Mock } from 'tasks/deployBuilds/mocks/buildMockERC20';
import { buildOracleMock } from 'tasks/deployBuilds/mocks/buildOracleMock';
import { loadVM } from 'tasks/utils';
import { buildEmptyYbStrategy } from './buildEmptyYbStrategy';
import { TContract } from '@tapioca-sdk/shared';

export const executeTestnetFinalStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
    yieldbox: TContract,
    verify?: boolean,
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
                (1e18).toString(), // 1 USDC = 1 USD
            ]),
        )
        .add(
            await buildERC20Mock(hre, DEPLOYMENT_NAMES.ARBITRUM_SGL_GLP, [
                'MOCK_ARB_SGL_GLP',
                'MOCK_ARB_SGL_GLP',
                (1e18).toString(),
                18,
                multicall.address,
            ]),
        )
        .add(
            await buildERC20Mock(hre, DEPLOYMENT_NAMES.MAINNET_SGL_DAI, [
                'MOCK_TOFT_MAINNET_SGL_DAI',
                'MOCK_TOFT_MAINNET_SGL_DAI',
                (1e18).toString(),
                18,
                multicall.address,
            ]),
        )
        .add(
            await buildEmptyYbStrategy(
                hre,
                DEPLOYMENT_NAMES.YB_SGL_ARB_GLP_STRATEGY,
                [
                    yieldbox.address, // Yieldbox
                    hre.ethers.constants.AddressZero, // Underlying token
                ],
                [
                    {
                        argPosition: 1,
                        deploymentName: DEPLOYMENT_NAMES.ARBITRUM_SGL_GLP,
                    },
                ],
            ),
        )
        .add(
            await buildEmptyYbStrategy(
                hre,
                DEPLOYMENT_NAMES.YB_SGL_MAINNET_DAI_STRATEGY,
                [
                    yieldbox.address, // Yieldbox
                    hre.ethers.constants.AddressZero, // Underlying token // TODO move name to config
                ],
                [
                    {
                        argPosition: 1,
                        deploymentName: DEPLOYMENT_NAMES.MAINNET_SGL_DAI,
                    },
                ],
            ),
        );

    await VM.execute();
    if (verify) {
        await VM.verify();
    }

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
        target: mockArbSglGlp.address,
        allowFailure: false,
        callData: mockArbSglGlp.interface.encodeFunctionData('approve', [
            yieldbox.address,
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
    calls.push({
        target: mockToftMainnetSglDai.address,
        allowFailure: false,
        callData: mockArbSglGlp.interface.encodeFunctionData('approve', [
            yieldbox.address,
            (1e18).toString(),
        ]),
    });

    await VM.executeMulticall(calls);
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const mockUsdc = getContract(hre, tag, 'MOCK_USDC');
    const mockArbSglGlp = await hre.ethers.getContractAt(
        'ERC20Mock',
        getGlobalContract(
            hre,
            tag,
            TAPIOCA_PROJECTS_NAME.TapiocaBar,
            DEPLOYMENT_NAMES.ARBITRUM_SGL_GLP,
        ).address,
    );
    const mockToftMainnetSglDai = await hre.ethers.getContractAt(
        'ERC20Mock',
        getGlobalContract(
            hre,
            tag,
            TAPIOCA_PROJECTS_NAME.TapiocaBar,
            DEPLOYMENT_NAMES.MAINNET_SGL_DAI,
        ).address,
    );

    return {
        mockUsdc,
        mockArbSglGlp,
        mockToftMainnetSglDai,
    };
}

function getGlobalContract(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    project: TAPIOCA_PROJECTS_NAME,
    contractName: string,
) {
    const contract = hre.SDK.db.findGlobalDeployment(
        project,
        hre.SDK.eChainId,
        contractName,
        tag,
    )!;
    if (!contract) {
        throw new Error(
            `[-] ${contractName} not found on project ${project} chain ${hre.network.name} tag ${tag}`,
        );
    }
    return contract;
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
