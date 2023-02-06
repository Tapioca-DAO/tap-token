import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TapiocaOptionBroker } from '../typechain';

export const setOracleMockRate__task = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const oracleMock = await hre.ethers.getContractAt('OracleMock', taskArgs.oracleAddress);
    await oracleMock.setRate(taskArgs.rate);
};

export const setTOBPaymentToken__task = async (
    taskArgs: { tknAddress: string; oracleAddress: string; oracleData: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const contractName = !!hre.network.tags['testnet'] ? 'TapiocaOptionBrokerMock' : 'TapiocaOptionBroker';
    const tOBAddress = (await SDK.API.utils.getDeployment('Tap-Token', contractName, await hre.getChainId()))?.address;
    const tOB = (await hre.ethers.getContractAt(contractName, tOBAddress)) as TapiocaOptionBroker;

    await tOB.setPaymentToken(taskArgs.tknAddress, taskArgs.oracleAddress, taskArgs.oracleData);
};
