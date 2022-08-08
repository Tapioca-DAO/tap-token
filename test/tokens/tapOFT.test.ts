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
        const amount = BN(1000).mul((1e18).toString());
        const initialAmount = BN(100000000).mul((1e18).toString());

        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(signer).createTAP(ethers.constants.AddressZero, amount)).to.be.reverted;
        await expect(tapiocaOFT0.connect(normalUser).createTAP(signer.address, amount)).to.be.revertedWith('unauthorized');
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.be.revertedWith('exceeds allowable mint amount');

        time_travel(50 * 86400);
        await tapiocaOFT0.updateMiningParameters();
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');
        time_travel(50 * 86400);
        await expect(tapiocaOFT0.connect(minter).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        expect(signerBalance.gt(initialAmount)).to.be.true;

        const totalSupply = await tapiocaOFT0.totalSupply();
        expect(totalSupply.eq(initialAmount.add(amount).add(amount))).to.be.true;
    });

    it('should not mint when paused', async () => {
        const amount = BN(1000).mul((1e18).toString());
        await tapiocaOFT0.pauseSendTokens(true);
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.be.reverted;
        await tapiocaOFT0.pauseSendTokens(false);
        time_travel(50 * 86400);
        await tapiocaOFT0.updateMiningParameters();
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

    it('should return the available supply', async () => {
        //for coverage
        const initialSupply = await tapiocaOFT0.INITIAL_SUPPLY();
        const available = await tapiocaOFT0.availableSupply();
        expect(available.eq(initialSupply)).to.be.true;
    });

    it('should return mintable in a specific timeframe', async () => {
        //for coverage
        const start = await tapiocaOFT0.startEpochTime();
        const end = start.add(10 * 86400);
        const end2 = start.add(2 * 365 * 86400);
        const end3 = start.add(200 * 365 * 86400);

        await expect(tapiocaOFT0.mintableInTimeframe(end, start)).to.be.reverted;
        await expect(tapiocaOFT0.mintableInTimeframe(start, end3)).to.be.reverted;
        await tapiocaOFT0.mintableInTimeframe(start, end);
        await tapiocaOFT0.mintableInTimeframe(start, end2);
    });

    it('should update mining params', async () => {
        //for coverage
        await expect(tapiocaOFT0.updateMiningParameters()).to.be.reverted;
        time_travel(2 * 365 * 86400);
        await tapiocaOFT0.updateMiningParameters();
        time_travel(2 * 365 * 86400);
        await tapiocaOFT0.updateMiningParameters();
    });

    it('should test start epoch write', async () => {
        //for coverage
        await tapiocaOFT0.startEpochTimeWrite();
        time_travel(2 * 365 * 86400);
        await tapiocaOFT0.startEpochTimeWrite();
    });

    it('should test emissions schedule for first year', async () => {
        const initialSupply = BN(100000000).mul((1e18).toString());
        const shouldMint = BN(34500000).mul((1e18).toString());
        const shouldMintMax = BN(34600000).mul((1e18).toString());
        time_travel(365 * 86400);
        await tapiocaOFT0.updateMiningParameters();
        const availableSupply = await tapiocaOFT0.availableSupply();
        const minted = availableSupply.sub(initialSupply);
        expect(minted.gt(shouldMint)).to.be.true;
        expect(minted.lt(shouldMintMax)).to.be.true;
    });

    it('should test emissions schedule for full period when updating parmeters each year', async () => {
        const initialSupply = BN(100000000).mul((1e18).toString());
        const shouldMint = BN(58100000).mul((1e18).toString());
        const shouldMintMax = BN(58200000).mul((1e18).toString());
        time_travel(365 * 86400);
        await tapiocaOFT0.updateMiningParameters();
        time_travel(365 * 86400);
        await tapiocaOFT0.updateMiningParameters();
        time_travel(365 * 86400);
        await tapiocaOFT0.updateMiningParameters();
        time_travel(365 * 86400);
        await tapiocaOFT0.updateMiningParameters();
        const availableSupply = await tapiocaOFT0.availableSupply();
        const minted = availableSupply.sub(initialSupply);
        expect(minted.gt(shouldMint)).to.be.true;
        expect(minted.lt(shouldMintMax)).to.be.true;
    });
});
