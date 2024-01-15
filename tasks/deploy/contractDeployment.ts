import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { registerContract } from '../../scripts/deployment.utils';
import { OracleMock__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';
import { loadVM } from '../utils';
import { buildERC20Mock } from '../deployBuilds/buildMockERC20';

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
        initialAmount: string;
        decimals: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    const signer = (await hre.ethers.getSigners())[0];
    const oracleMock = await buildERC20Mock(hre, taskArgs.deploymentName, [
        taskArgs.name,
        taskArgs.name,
        taskArgs.initialAmount,
        taskArgs.decimals,
        signer.address,
    ]);

    const VM = await loadVM(hre, 'default');
    VM.add(oracleMock);
    // Add and execute
    VM.save();
    await VM.verify();
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
            name: taskArgs.deploymentName,
            address: oracleMock.address,
            meta: {
                args: [taskArgs.erc20Name, taskArgs.erc20Name, taskArgs.rate],
            },
        },
    ]);

    // Add and execute
    VM.save();
    await VM.verify();
};
