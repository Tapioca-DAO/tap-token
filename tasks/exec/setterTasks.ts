import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TapiocaOptionBroker } from '../../typechain';

export const setOracleMockRate__task = async (
    taskArgs: { rate: string; oracleAddress: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const oracleMock = await hre.ethers.getContractAt(
        'OracleMock',
        taskArgs.oracleAddress,
    );
    await (await oracleMock.setRate(taskArgs.rate)).wait();
};

export const setTOBPaymentToken__task = async (
    taskArgs: {
        tknAddress: string;
        oracleAddress: string;
        oracleData: string;
        tag?: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    const contractName = !!hre.network.tags['testnet']
        ? 'TapiocaOptionBrokerMock'
        : 'TapiocaOptionBroker';
    const tOBAddress = SDK.API.db.getLocalDeployment(
        await hre.getChainId(),
        contractName,
        taskArgs.tag,
    )?.address;
    if (!tOBAddress) throw new Error('TapiocaOptionBroker not found');
    const tOB = (await hre.ethers.getContractAt(
        contractName,
        tOBAddress,
    )) as TapiocaOptionBroker;

    await (
        await tOB.setPaymentToken(
            taskArgs.tknAddress,
            taskArgs.oracleAddress,
            taskArgs.oracleData,
        )
    ).wait();
};

export const setTOLPRegisterSingularity__task = async (
    taskArgs: {
        sglAddress: string;
        assetId: string;
        weight: string;
        tag?: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    const tOLPAdress = SDK.API.db.getLocalDeployment(
        await hre.getChainId(),
        'TapiocaOptionLiquidityProvision',
        taskArgs.tag,
    )?.address;
    if (!tOLPAdress)
        throw new Error('TapiocaOptionLiquidityProvision not found');
    const tOLP = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        tOLPAdress,
    );

    await (
        await tOLP.registerSingularity(
            taskArgs.sglAddress,
            taskArgs.assetId,
            taskArgs.weight,
        )
    ).wait();
};

export const setTOLPUnregisterSingularity__task = async (
    taskArgs: { sglAddress: string; tag?: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const tOLPAdress = SDK.API.db.getLocalDeployment(
        await hre.getChainId(),
        'TapiocaOptionLiquidityProvision',
        taskArgs.tag,
    )?.address;
    if (!tOLPAdress)
        throw new Error('TapiocaOptionLiquidityProvision not found');
    const tOLP = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        tOLPAdress,
    );

    await (await tOLP.unregisterSingularity(taskArgs.sglAddress)).wait();
};
