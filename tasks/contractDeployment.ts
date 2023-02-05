import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { registerContract, updateDeployments } from '../deploy/utils';

export const deployVesting__task = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const tContractObj = await registerContract(hre, 'Vesting', taskArgs.deploymentName, [
        taskArgs.token,
        taskArgs.cliff,
        taskArgs.duration,
    ]);
    await updateDeployments([tContractObj], await hre.getChainId());
};

export const deployERC20Mock__task = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const tContractObj = await registerContract(hre, 'ERC20Mock', taskArgs.deploymentName, [taskArgs.initialAmount, taskArgs.decimals]);
    await updateDeployments([tContractObj], await hre.getChainId());
};

export const deployOracleMock__task = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const tContractObj = await registerContract(hre, 'OracleMock', taskArgs.deploymentName, [taskArgs.erc20Name]);
    await updateDeployments([tContractObj], await hre.getChainId());
};
