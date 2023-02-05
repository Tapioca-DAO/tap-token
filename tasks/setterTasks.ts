import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const setOracleMockRate__task = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const oracleMock = await hre.ethers.getContractAt('OracleMock', taskArgs.oracleAddress);
    await oracleMock.setRate(taskArgs.rate);
};
