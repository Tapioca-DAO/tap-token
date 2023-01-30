import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish } from 'ethers';
import hre, { ethers } from 'hardhat';
import { ERC20Mock, YieldBox } from '../../typechain';
import { BN } from '../test.utils';

export const setupFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];
    const users = (await hre.ethers.getSigners()).splice(1);

    const chainId = (await ethers.provider.getNetwork()).chainId;

    // LZ Endpoint Mocks
    const LZEndpointMockCurrentChain = await (await ethers.getContractFactory('LZEndpointMock')).deploy(chainId);
    const LZEndpointMockGovernance = await (await ethers.getContractFactory('LZEndpointMock')).deploy(11);

    // Tap OFT
    const _to = signer.address;
    const tapOFT = await (
        await ethers.getContractFactory('TapOFT')
    ).deploy(LZEndpointMockCurrentChain.address, _to, _to, _to, _to, chainId);

    // YieldBox
    const _wrappedNative = await (await ethers.getContractFactory('WETH9Mock')).deploy();
    const _uriBuilder = await (await ethers.getContractFactory('YieldBoxURIBuilder')).deploy();
    const yieldBox = await (await ethers.getContractFactory('YieldBox')).deploy(_wrappedNative.address, _uriBuilder.address);

    // oTAP
    const tapOracleMock = await (await ethers.getContractFactory('OracleMock')).deploy();
    await tapOracleMock.setRate(BN(33e17));
    const tOLP = await (await ethers.getContractFactory('TapiocaOptionLiquidityProvision')).deploy(yieldBox.address);
    const oTAP = await (await ethers.getContractFactory('OTAP')).deploy();
    const tOB = await (
        await ethers.getContractFactory('TapiocaOptionBroker')
    ).deploy(tOLP.address, oTAP.address, tapOFT.address, tapOracleMock.address);

    // Deploy a "virtual" market
    const sglTokenMock = await (await ethers.getContractFactory('ERC20Mock')).deploy(0, 18);
    const sglTokenMockAsset = await yieldBox.assetCount();
    const sglTokenMock2 = await (await ethers.getContractFactory('ERC20Mock')).deploy(0, 18);
    const sglTokenMock2Asset = sglTokenMockAsset.add(1);

    await deployNewMarket(yieldBox, sglTokenMock);
    await deployNewMarket(yieldBox, sglTokenMock2);

    // Deploy payment tokens
    const stableMock = await (await ethers.getContractFactory('ERC20Mock')).deploy(0, 6);
    const ethMock = await (await ethers.getContractFactory('ERC20Mock')).deploy(0, 18);
    const stableMockOracle = await (await ethers.getContractFactory('OracleMock')).deploy();
    const ethMockOracle = await (await ethers.getContractFactory('OracleMock')).deploy();

    await stableMockOracle.setRate(1e6);
    await ethMockOracle.setRate(BN(1e18).mul(1200));

    return {
        // signers
        signer,
        users,

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

async function deployNewMarket(yieldBox: YieldBox, tkn: ERC20Mock) {
    await yieldBox.registerAsset(1, tkn.address, ethers.constants.AddressZero, 0);
}
