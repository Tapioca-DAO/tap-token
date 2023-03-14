import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish } from 'ethers';
import hre, { ethers } from 'hardhat';
import { YieldBox, ERC20Mock } from '../../typechain';
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
    const LZEndpointMockCurrentChain = await (
        await ethers.getContractFactory('LZEndpointMock')
    ).deploy(chainId);
    const LZEndpointMockGovernance = await (
        await ethers.getContractFactory('LZEndpointMock')
    ).deploy(11);

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
        chainId,
        signer.address,
    );

    // YieldBox
    const _wrappedNative = await (
        await ethers.getContractFactory('WETH9Mock')
    ).deploy();
    const _uriBuilder = await (
        await ethers.getContractFactory('YieldBoxURIBuilder')
    ).deploy();
    const yieldBox = await (
        await ethers.getContractFactory('YieldBox')
    ).deploy(_wrappedNative.address, _uriBuilder.address);

    // oTAP
    const tapOracleMock = await (
        await ethers.getContractFactory('OracleMock')
    ).deploy('TAP');
    await tapOracleMock.setRate(BN(33e7));
    const tOLP = await (
        await ethers.getContractFactory('TapiocaOptionLiquidityProvision')
    ).deploy(yieldBox.address, signer.address);
    const oTAP = await (await ethers.getContractFactory('OTAP')).deploy();
    const tOB = await (
        await ethers.getContractFactory('TapiocaOptionBroker')
    ).deploy(
        tOLP.address,
        oTAP.address,
        tapOFT.address,
        paymentTokenBeneficiary.address,
        signer.address,
    );
    await tOB.setTapOracle(tapOracleMock.address, '0x00');

    // Deploy a "virtual" market
    const sglTokenMock = await (
        await ethers.getContractFactory('ERC20Mock')
    ).deploy('sglTokenMock', 'STM', 0, 18);
    const sglTokenMockAsset = await yieldBox.assetCount();
    const sglTokenMockStrategy = await (
        await ethers.getContractFactory('ERC20WithoutStrategy')
    ).deploy(yieldBox.address, sglTokenMock.address);

    const sglTokenMock2 = await (
        await ethers.getContractFactory('ERC20Mock')
    ).deploy('sglTokenMock', 'STM', 0, 18);
    const sglTokenMock2Asset = sglTokenMockAsset.add(1);
    const sglTokenMock2Strategy = await (
        await ethers.getContractFactory('ERC20WithoutStrategy')
    ).deploy(yieldBox.address, sglTokenMock2.address);

    await deployNewMarket(yieldBox, sglTokenMock, sglTokenMockStrategy.address);
    await deployNewMarket(
        yieldBox,
        sglTokenMock2,
        sglTokenMock2Strategy.address,
    );

    // Deploy payment tokens
    const stableMock = await (
        await ethers.getContractFactory('ERC20Mock')
    ).deploy('StableMock', 'STBLM', 0, 6);
    const ethMock = await (
        await ethers.getContractFactory('ERC20Mock')
    ).deploy('wethMock', 'WETHM', 0, 18);
    const stableMockOracle = await (
        await ethers.getContractFactory('OracleMock')
    ).deploy('StableMockOracle');
    const ethMockOracle = await (
        await ethers.getContractFactory('OracleMock')
    ).deploy('WETHMockOracle');

    await stableMockOracle.setRate(1e8);
    await ethMockOracle.setRate(BN(1e8).mul(1200));

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
    const strat = await (
        await ethers.getContractFactory('YieldBoxVaultStrat')
    ).deploy(yieldBox.address, tkn.address, name, desc);
    await yieldBox.registerAsset(1, tkn.address, strat.address, 0);
}
