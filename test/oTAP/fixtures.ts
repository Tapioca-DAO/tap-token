import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish } from 'ethers';
import hre, { ethers } from 'hardhat';
import { ERC20Mock, YieldBox } from '../../typechain';

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

    // tOLP

    // oTAP
    const tOLP = await (await ethers.getContractFactory('TapiocaOptionLiquidityProvision')).deploy(yieldBox.address);
    const oTAP = await (await ethers.getContractFactory('OTAP')).deploy();
    const tOB = await (await ethers.getContractFactory('TapiocaOptionBroker')).deploy(tOLP.address, oTAP.address, tapOFT.address);

    // Deploy a "virtual" market
    const sglTokenMock = await (await ethers.getContractFactory('ERC20Mock')).deploy(0);
    const sglTokenMockAsset = await yieldBox.assetCount();
    const sglTokenMock2 = await (await ethers.getContractFactory('ERC20Mock')).deploy(0);
    const sglTokenMock2Asset = sglTokenMockAsset.add(1);

    await deployNewMarket(yieldBox, sglTokenMock);
    await deployNewMarket(yieldBox, sglTokenMock2);

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

        // funcs
        deployNewMarket,
    };
};

async function deployNewMarket(yieldBox: YieldBox, tkn: ERC20Mock) {
    await yieldBox.registerAsset(1, tkn.address, ethers.constants.AddressZero, 0);
}
