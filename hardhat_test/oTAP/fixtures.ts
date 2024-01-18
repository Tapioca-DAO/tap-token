import hre, { ethers } from 'hardhat';
import {
    ERC20Mock,
    ERC20Mock__factory,
    LZEndpointMock__factory,
    OracleMock__factory,
} from '@tapioca-sdk/typechain/tapioca-mocks';
import {
    ERC20WithoutStrategy__factory,
    ERC20StrategyMock__factory,
    YieldBoxURIBuilder__factory,
    YieldBox__factory,
    YieldBox,
} from '@tapioca-sdk/typechain/YieldBox';

import { BN } from '../test.utils';

export const setupFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];
    const users = (await hre.ethers.getSigners()).splice(1);
    const paymentTokenBeneficiary = new hre.ethers.Wallet(
        hre.ethers.Wallet.createRandom().privateKey,
        hre.ethers.provider,
    );

    const chainId = (await ethers.provider.getNetwork()).chainId;

    // LZ Endpoint Mocks
    const LZEndpointMock = new LZEndpointMock__factory(signer);
    const LZEndpointMockCurrentChain = await LZEndpointMock.deploy(chainId);
    const LZEndpointMockGovernance = await LZEndpointMock.deploy(11);

    // Tap OFT
    const _to = signer.address;
    const tapOFT = await (
        await ethers.getContractFactory('TapOFT')
    ).deploy(
        LZEndpointMockCurrentChain.address,
        _to,
        _to,
        _to,
        _to,
        _to,
        _to,
        chainId,
        signer.address,
    );

    // YieldBox
    const _wrappedNative = await new ERC20Mock__factory(signer).deploy(
        'WETH',
        'WETH',
        0,
        18,
        signer.address,
    );
    const _uriBuilder = await new YieldBoxURIBuilder__factory(signer).deploy();
    const yieldBox = await new YieldBox__factory(signer).deploy(
        _wrappedNative.address,
        _uriBuilder.address,
    );

    const OracleMock = new OracleMock__factory(signer);

    // oTAP
    const tapOracleMock = await OracleMock.deploy('TAP', 'TAP', BN(33e17));
    const tOLP = await (
        await ethers.getContractFactory('TapiocaOptionLiquidityProvision')
    ).deploy(
        yieldBox.address,
        604800, // 7 days
        signer.address,
    );
    const oTAP = await (await ethers.getContractFactory('OTAP')).deploy();
    const tOB = await (
        await hre.ethers.getContractFactory('TapiocaOptionBroker')
    ).deploy(
        tOLP.address,
        oTAP.address,
        tapOFT.address,
        paymentTokenBeneficiary.address,
        604800, // 7 days
        signer.address,
    );
    await tOB.setTapOracle(tapOracleMock.address, '0x00');

    // Deploy a "virtual" market
    const ERC20Mock = new ERC20Mock__factory(signer);
    const sglTokenMock = await ERC20Mock.deploy(
        'sglTokenMock',
        'STM',
        0,
        18,
        signer.address,
    );
    await sglTokenMock.updateMintLimit(ethers.constants.MaxUint256);

    const ERC20WithoutStrategy = new ERC20WithoutStrategy__factory(signer);
    const sglTokenMockAsset = await yieldBox.assetCount();
    const sglTokenMockStrategy = await ERC20WithoutStrategy.deploy(
        yieldBox.address,
        sglTokenMock.address,
    );

    const sglTokenMock2 = await ERC20Mock.deploy(
        'sglTokenMock',
        'STM',
        0,
        18,
        signer.address,
    );
    await sglTokenMock2.updateMintLimit(ethers.constants.MaxUint256);
    const sglTokenMock2Asset = sglTokenMockAsset.add(1);
    const sglTokenMock2Strategy = await new ERC20WithoutStrategy__factory(
        signer,
    ).deploy(yieldBox.address, sglTokenMock2.address);

    await deployNewMarket(yieldBox, sglTokenMock, sglTokenMockStrategy.address);
    await deployNewMarket(
        yieldBox,
        sglTokenMock2,
        sglTokenMock2Strategy.address,
    );

    // Deploy payment tokens
    const stableMock = await ERC20Mock.deploy(
        'StableMock',
        'STBLM',
        0,
        6,
        signer.address,
    );
    await stableMock.updateMintLimit(ethers.constants.MaxUint256);
    const ethMock = await ERC20Mock.deploy(
        'wethMock',
        'WETHM',
        0,
        18,
        signer.address,
    );
    await ethMock.updateMintLimit(ethers.constants.MaxUint256);

    const stableMockOracle = await OracleMock.deploy(
        'StableMockOracle',
        'SMO',
        (1e18).toString(),
    );
    const ethMockOracle = await OracleMock.deploy(
        'WETHMockOracle',
        'WMO',
        BN(1e18).mul(1200),
    );

    return {
        // signers
        signer,
        users,
        paymentTokenBeneficiary,

        // vars
        LZEndpointMockCurrentChain,
        LZEndpointMockGovernance,
        tapOFT,
        yieldBox,
        tOLP,
        oTAP,
        tOB,

        // Markets
        sglTokenMock,
        sglTokenMockAsset,
        sglTokenMock2,
        sglTokenMock2Asset,
        tapOracleMock,

        // Payment tokens
        stableMock,
        ethMock,
        stableMockOracle,
        ethMockOracle,

        // funcs
        deployNewMarket,
    };
};

async function deployNewMarket(
    yieldBox: YieldBox,
    tkn: ERC20Mock,
    name = 'test',
    desc = 'test',
) {
    const signer = (await hre.ethers.getSigners())[0];
    const strat = await new ERC20StrategyMock__factory(signer).deploy(
        yieldBox.address,
        tkn.address,
    );
    await yieldBox.registerAsset(1, tkn.address, strat.address, 0);
}
