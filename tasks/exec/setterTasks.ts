import {
    ERC20WithoutStrategy__factory,
    YieldBox__factory,
} from '@tapioca-sdk/typechain/YieldBox';
import {
    TapiocaOptionBroker,
    TapiocaOptionLiquidityProvision__factory,
} from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import { loadVM } from 'tasks/utils';

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
        weight: string;
        tag?: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    const signer = (await hre.ethers.getSigners())[0];

    const tOLPAddress = SDK.API.db.findLocalDeployment(
        hre.SDK.eChainId,
        DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
        taskArgs.tag,
    )?.address;

    if (!tOLPAddress)
        throw new Error('TapiocaOptionLiquidityProvision not found');

    const tOLP = TapiocaOptionLiquidityProvision__factory.connect(
        tOLPAddress,
        signer,
    );

    const yieldBox = YieldBox__factory.connect(await tOLP.yieldBox(), signer);

    const strategy = await new ERC20WithoutStrategy__factory(signer).deploy(
        yieldBox.address,
        taskArgs.sglAddress,
    );
    await strategy.deployed();

    await (
        await yieldBox.registerAsset(
            1,
            taskArgs.sglAddress,
            strategy.address,
            0,
        )
    ).wait();

    const assetID = await yieldBox.ids(
        1,
        taskArgs.sglAddress,
        strategy.address,
        0,
    );

    const VM = await loadVM(hre, taskArgs.tag);
    await VM.executeMulticall([
        {
            target: tOLP.address,
            allowFailure: false,
            callData: tOLP.interface.encodeFunctionData('registerSingularity', [
                taskArgs.sglAddress,
                assetID,
                taskArgs.weight,
            ]),
        },
    ]);
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
