import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { LZEndpointMock, TapOFT } from '../../typechain';

import { deployLZEndpointMock, deployTapiocaOFT, BN, time_travel } from '../test.utils';

describe('tapOFT', () => {
    let signer: SignerWithAddress;
    let minter: SignerWithAddress;
    let normalUser: SignerWithAddress;

    let LZEndpointMock0: LZEndpointMock;
    let LZEndpointMock1: LZEndpointMock;

    let tapiocaOFT0: TapOFT;
    let tapiocaOFT1: TapOFT;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        minter = (await ethers.getSigners())[1];
        normalUser = (await ethers.getSigners())[2];

        LZEndpointMock0 = await deployLZEndpointMock(0);
        LZEndpointMock1 = await deployLZEndpointMock(1);

        tapiocaOFT0 = (await deployTapiocaOFT(LZEndpointMock0.address, signer.address)) as TapOFT;
        tapiocaOFT1 = (await deployTapiocaOFT(LZEndpointMock1.address, signer.address)) as TapOFT;
    });

    it('should check initial state', async () => {
        expect(await tapiocaOFT0.decimals()).eq(18);
        expect(await tapiocaOFT1.decimals()).eq(18);

        expect(await LZEndpointMock0.getChainId()).eq(0);
        expect(await LZEndpointMock1.getChainId()).eq(1);

        expect(await tapiocaOFT0.paused()).to.be.false;
        expect(await tapiocaOFT1.paused()).to.be.false;

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        const totalSupply = BN(100000000).mul((1e18).toString());
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not be able to deploy with an empty LayerZero endpoint', async () => {
        const factory = await ethers.getContractFactory('TapOFT');
        await expect(
            factory.deploy(
                ethers.constants.AddressZero,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
            ),
        ).to.be.reverted;
    });

    it('should set minter', async () => {
        const currentMinter = await tapiocaOFT0.minter();
        expect(currentMinter).to.eq(ethers.constants.AddressZero);
        await expect(tapiocaOFT0.connect(minter).setMinter(minter.address)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setMinter(ethers.constants.AddressZero)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');
    });

    it('should mint more', async () => {
        const amount = BN(100000000).mul((1e18).toString());
        const finalAmount = BN(300000000).mul((1e18).toString());

        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(normalUser).createTAP(signer.address, amount)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');
        await expect(tapiocaOFT0.connect(minter).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        expect(signerBalance).to.eq(finalAmount);

        const totalSupply = await tapiocaOFT0.totalSupply();
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not mint when paused', async () => {
        const amount = BN(100000000).mul((1e18).toString());
        await tapiocaOFT0.pauseSendTokens(true);
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.be.reverted;
        await tapiocaOFT0.pauseSendTokens(false);
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');
    });

    it('should burn', async () => {
        const amount = BN(20000000).mul((1e18).toString());
        const finalAmount = BN(60000000).mul((1e18).toString());

        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(normalUser).removeTAP(signer.address, amount)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).removeTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Burned');
        await expect(tapiocaOFT0.connect(minter).removeTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Burned');

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        expect(signerBalance).to.eq(finalAmount);

        const totalSupply = await tapiocaOFT0.totalSupply();
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not burn when paused', async () => {
        const amount = BN(100000000).mul((1e18).toString());
        await tapiocaOFT0.pauseSendTokens(true);
        await expect(tapiocaOFT0.connect(signer).removeTAP(signer.address, amount)).to.be.reverted;
        await tapiocaOFT0.pauseSendTokens(false);
        await expect(tapiocaOFT0.connect(signer).removeTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Burned');
    });
});
