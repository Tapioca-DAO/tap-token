import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { constants } from '../scripts/deployment.utils';
import {
    Multicall3__factory,
    TapiocaOptionLiquidityProvision__factory,
    TapOFT__factory,
    YieldBoxURIBuilder__factory,
    YieldBox__factory,
} from '../typechain';

import { DeployerVM, IDeployerVMAdd } from './deployerVM';

// TODO remove this
const buildAndAddYieldBox = async (
    hre: HardhatRuntimeEnvironment,
): Promise<
    [
        IDeployerVMAdd<YieldBoxURIBuilder__factory>,
        IDeployerVMAdd<YieldBox__factory>,
    ]
> => {
    const ybURIBuilder = await hre.ethers.getContractFactory(
        'YieldBoxURIBuilder',
    );
    const yb = await hre.ethers.getContractFactory('YieldBox');

    return [
        {
            contract: ybURIBuilder,
            deploymentName: 'YieldBoxURIBuilder',
            args: [],
        },
        {
            contract: yb,
            deploymentName: 'YieldBox',
            args: [
                // Wrapped Native (we don't need it for now, so we replace it with a dummy value)
                hre.ethers.constants.AddressZero,
                // YieldBoxURIBuilder, to be replaced by VM
                hre.ethers.constants.AddressZero,
            ],
            dependsOn: [
                { argPosition: 0, deploymentName: 'YieldBoxURIBuilder' }, // dummy value
                { argPosition: 1, deploymentName: 'YieldBoxURIBuilder' },
            ],
        },
    ];
};

const buildAndAddTapOFT = async (
    hre: HardhatRuntimeEnvironment,
): Promise<IDeployerVMAdd<TapOFT__factory>> => {
    const chainId = await hre.getChainId();
    const lzEndpoint = constants[chainId as '5'].address as string;
    const contributorAddress = constants.teamAddress;
    const investorAddress = constants.advisorAddress;
    const lbpAddress = constants.daoAddress;
    const airdropAddress = constants.seedAddress;
    const daoAddress = constants.daoAddress;
    const governanceChainId = constants.governanceChainId.toString();

    return {
        contract: await hre.ethers.getContractFactory('TapOFT'),
        deploymentName: 'TapOFT',
        args: [
            lzEndpoint,
            contributorAddress,
            investorAddress,
            lbpAddress,
            daoAddress,
            airdropAddress,
            governanceChainId,
        ],
    };
};

const buildAndAddTOLP = async (
    hre: HardhatRuntimeEnvironment,
    signerAddr: string,
): Promise<IDeployerVMAdd<TapiocaOptionLiquidityProvision__factory>> => ({
    contract: await hre.ethers.getContractFactory(
        'TapiocaOptionLiquidityProvision',
    ),
    deploymentName: 'TapiocaOptionLiquidityProvision',
    args: [
        // To be replaced by VM
        hre.ethers.constants.AddressZero,
        signerAddr,
    ],
    dependsOn: [{ argPosition: 0, deploymentName: 'YieldBox' }],
});

// TODO - Refactor steps to external function to lighten up the task
export const deployStack__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    // Settings
    const signer = (await hre.ethers.getSigners())[0];
    const VM = new DeployerVM(hre, {
        multicall: Multicall3__factory.connect(
            hre.SDK.config.MULTICALL_ADDRESS,
            signer,
        ),
    });

    // TODO - To remove
    // Build YieldBox on the go:)
    const yb = await buildAndAddYieldBox(hre);
    VM.add(yb[0]).add(yb[1]);

    // Build contracts
    VM.add(await buildAndAddTapOFT(hre)).add(
        await buildAndAddTOLP(hre, signer.address),
    );

    // Add and execute
    await VM.execute();

    // Testing
    const list = VM.list();
    console.log(JSON.stringify(list, null, 2));
    const tap = await hre.ethers.getContractAt(
        'YieldBox',
        list.find((e) => e.name === 'YieldBox')?.address ?? '',
    );
    console.log(await tap.DOMAIN_SEPARATOR());
};
