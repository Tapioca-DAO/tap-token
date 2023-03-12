import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { TapiocaOptionBroker } from '../typechain';

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
    const tOLP = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        tOLPAdress,
    );

    await (await tOLP.unregisterSingularity(taskArgs.sglAddress)).wait();
};

export const setYieldBoxRegisterAsset__task = async (
    taskArgs: {
        tknAddress: string;
        tknId?: string;
        tknType?: string;
        strategy?: string;
        strategyName?: string;
        strategyDesc?: string;
        tag?: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    const yieldBoxAddress = SDK.API.db.getLocalDeployment(
        await hre.getChainId(),
        'YieldBox',
        taskArgs.tag,
    )?.address;
    const yb = await hre.ethers.getContractAt('YieldBox', yieldBoxAddress);

    const strat = await (
        await hre.ethers.getContractFactory('YieldBoxVaultStrat')
    ).deploy(
        yb.address,
        taskArgs.tknAddress,
        taskArgs.strategyName ?? 'YBVaultStrat',
        taskArgs.strategyDesc ?? 'YBVaultStrat',
    );
    await strat.deployed();
    await (
        await yb.registerAsset(
            taskArgs.tknType ?? 1,
            taskArgs.tknAddress,
            taskArgs.strategy ?? strat.address,
            taskArgs.tknId ?? 0,
        )
    ).wait();
    console.log('[+] Asset ID: ', await yb.assetCount());
    return await yb.assetCount();
};
