import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    YieldBoxURIBuilder__factory,
    YieldBox__factory,
} from '../../typechain';
import { IDeployerVMAdd } from '../deployerVM';

// TODO remove this
export const buildYieldBoxMock = async (
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
    const yb = await hre.ethers.getContractFactory('YieldBoxMock');

    return [
        {
            contract: ybURIBuilder,
            deploymentName: 'YieldBoxURIBuilder',
            args: [],
        },
        {
            contract: yb,
            deploymentName: 'YieldBoxMock',
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
