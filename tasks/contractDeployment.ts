import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { registerContract } from '../scripts/deployment.utils';

export const deployVesting__task = async (
    taskArgs: {
        deploymentName: string;
        token: string;
        cliff: string;
        duration: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    await registerContract(hre, 'Vesting', taskArgs.deploymentName, [
        taskArgs.token,
        taskArgs.cliff,
        taskArgs.duration,
    ]);
};

export const deployERC20Mock__task = async (
    taskArgs: {
        deploymentName: string;
        name: string;
        symbol: string;
        initialAmount: string;
        decimals: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    const args = [
        taskArgs.name,
        taskArgs.symbol,
        taskArgs.initialAmount,
        taskArgs.decimals,
    ];
    await registerContract(hre, 'ERC20Mock', taskArgs.deploymentName, args);
};

export const deployOracleMock__task = async (
    taskArgs: { deploymentName: string; erc20Name: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const args = [taskArgs.erc20Name];
    await registerContract(hre, 'OracleMock', taskArgs.deploymentName, args);
};
