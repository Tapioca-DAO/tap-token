import { OracleMock__factory } from '@tapioca-sdk/typechain/tapioca-mocks';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { registerContract } from '../../hardhat_scripts/deployment.utils';
import { loadVM } from '../utils';

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
    taskArgs: { deploymentName: string; erc20Name: string; rate: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const oracleMock = await new OracleMock__factory()
        .connect((await hre.ethers.getSigners())[0])
        .deploy(taskArgs.erc20Name, taskArgs.erc20Name, taskArgs.rate);

    console.log(`[+] Tx: ${oracleMock.deployTransaction.hash}}`);
    await oracleMock.deployed();

    const VM = await loadVM(hre, 'default');
    VM.load([
        {
            address: oracleMock.address,
            name: taskArgs.deploymentName,
            meta: {
                args: [taskArgs.erc20Name, taskArgs.erc20Name, taskArgs.rate],
            },
        },
    ]);

    // Add and execute
    VM.save();
};
