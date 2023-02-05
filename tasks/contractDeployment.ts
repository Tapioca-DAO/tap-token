import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { registerContract, updateDeployments, verify } from '../scripts/deployment.utils';

export const deployVesting__task = async (
    taskArgs: { deploymentName: string; token: string; cliff: string; duration: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const tContractObj = await registerContract(hre, 'Vesting', taskArgs.deploymentName, [
        taskArgs.token,
        taskArgs.cliff,
        taskArgs.duration,
    ]);
    await verify(hre, tContractObj.address, [taskArgs.token, taskArgs.cliff, taskArgs.duration]);
    console.log('[+] Deployed Vesting at', tContractObj.address);
    await updateDeployments([tContractObj], await hre.getChainId());
};

export const deployERC20Mock__task = async (
    taskArgs: { deploymentName: string; initialAmount: string; decimals: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const tContractObj = await registerContract(hre, 'ERC20Mock', taskArgs.deploymentName, [taskArgs.initialAmount, taskArgs.decimals]);
    await verify(hre, tContractObj.address, [taskArgs.initialAmount, taskArgs.decimals]);
    console.log('[+] Deployed ERC20Mock at', tContractObj.address);
    await updateDeployments([tContractObj], await hre.getChainId());
};

export const deployOracleMock__task = async (taskArgs: { deploymentName: string; erc20Name: string }, hre: HardhatRuntimeEnvironment) => {
    const tContractObj = await registerContract(hre, 'OracleMock', taskArgs.deploymentName, [taskArgs.erc20Name]);
    await verify(hre, tContractObj.address, [taskArgs.erc20Name]);
    console.log('[+] Deployed OracleMock at', tContractObj.address);
    await updateDeployments([tContractObj], await hre.getChainId());
};
