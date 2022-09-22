import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { LZEndpointMock, EsTapOFT, TapOFT, EsTapVesting } from '../../typechain/';

import { deployLZEndpointMock, deployEsTap, deployTapiocaOFT, deployEsTapVesting, BN, time_travel } from '../test.utils';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('esTAP vesting', () => {
    let signer: SignerWithAddress;
    let minter: SignerWithAddress;
    let burner: SignerWithAddress;

    let tap: TapOFT;
    let esTap: EsTapOFT;
    let LZEndpointMock: LZEndpointMock;
    let esTapVesting: EsTapVesting;

    async function register() {
        signer = (await ethers.getSigners())[0];
        minter = (await ethers.getSigners())[1];
        burner = (await ethers.getSigners())[2];
        const chainId = (await ethers.provider.getNetwork()).chainId;
        LZEndpointMock = await deployLZEndpointMock(chainId);
        tap = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        esTap = (await deployEsTap(LZEndpointMock.address, minter.address, burner.address)) as EsTapOFT;
        esTapVesting = (await deployEsTapVesting(tap.address, esTap.address)) as EsTapVesting;
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should check initial state', async () => {
        expect((await esTapVesting.tapToken()).toLowerCase()).eq(tap.address.toLowerCase());
        expect((await esTapVesting.esTapToken()).toLowerCase()).eq(esTap.address.toLowerCase());
        const defaultDuration = 90 * 86400;
        let vestingDuration = await esTapVesting.vestingDuration();
        expect(vestingDuration.eq(defaultDuration)).to.be.true;
    });

    it('should not create with invalid data', async () => {
        const factory = await ethers.getContractFactory('esTapVesting');
        await expect(factory.deploy(tap.address, ethers.constants.AddressZero)).to.be.revertedWith('esTAP token not valid');
        await expect(factory.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero)).to.be.revertedWith('TAP token not valid');
    });

    it('should get empty vesting before any lock', async () => {
        const vestingData = await esTapVesting.getVesting(signer.address);
        expect(vestingData[3].eq(0)).to.be.true;

        const claimable = await esTapVesting.claimableAmount(signer.address);
        expect(claimable.eq(0)).to.be.true;
    });

    it('should blacklist', async () => {
        let status = await esTapVesting.blacklisted(minter.address);
        expect(status).to.be.false;

        await expect(esTapVesting.connect(minter).blacklistUpdate(minter.address, true)).to.be.reverted;
        await esTapVesting.connect(signer).blacklistUpdate(minter.address, true);

        status = await esTapVesting.blacklisted(minter.address);
        expect(status).to.be.true;
    });

    it('should update the vesting duration', async () => {
        const defaultDuration = 90 * 86400;
        const newDuration = 180 * 86400;
        let vestingDuration = await esTapVesting.vestingDuration();
        expect(vestingDuration.eq(defaultDuration)).to.be.true;

        await expect(esTapVesting.connect(minter).updateVestingDuration(newDuration)).to.be.reverted;
        await expect(esTapVesting.updateVestingDuration(newDuration)).to.emit(esTapVesting, 'VestingDurationUpdated');
        vestingDuration = await esTapVesting.vestingDuration();
        expect(vestingDuration.eq(newDuration)).to.be.true;
    });

    it('should vest', async () => {
        const amount = BN(1000).mul((1e18).toString());

        let esTapBalance = await esTap.balanceOf(burner.address);
        expect(esTapBalance.eq(0)).to.be.true;

        //blacklist
        await esTapVesting.connect(signer).blacklistUpdate(burner.address, true);
        await expect(esTapVesting.connect(burner).vest(amount)).to.be.revertedWith('blacklisted');
        await esTapVesting.connect(signer).blacklistUpdate(burner.address, false);

        await expect(esTapVesting.connect(burner).vest(amount)).to.be.reverted;

        //get esTap
        await esTap.connect(minter).mintFor(burner.address, amount); //FeeDistributor should be the real minter
        esTapBalance = await esTap.balanceOf(burner.address);
        expect(esTapBalance.eq(amount)).to.be.true;

        //vest
        await expect(esTapVesting.connect(burner).vest(amount)).to.be.reverted;
        await esTap.connect(burner).approve(esTapVesting.address, amount);
        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');
        esTapBalance = await esTap.balanceOf(burner.address);
        expect(esTapBalance.eq(0)).to.be.true;

        let vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount)).to.be.true;
    });

    it('should force claim', async () => {
        const amount = BN(1000).mul((1e18).toString());
        const maxClaimable = BN(550).mul((1e18).toString());

        await tap.connect(signer).transfer(esTapVesting.address, amount); //FeeDistributor should be the real sender
        await esTap.connect(minter).mintFor(burner.address, amount);
        await esTap.connect(burner).approve(esTapVesting.address, amount);
        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');

        let tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.eq(0)).to.be.true;

        await esTap.setBurner(esTapVesting.address);

        const forceClaimData = await esTapVesting.connect(burner).callStatic.forceClaim();
        expect(forceClaimData[0].gt(0)).to.be.true;
        expect(forceClaimData[1].gt(0)).to.be.true;

        await esTapVesting.connect(burner).forceClaim();
        tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.lt(maxClaimable)).to.be.true;

        let vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(0)).to.be.true;
        expect(vestingData[5].eq(tapBalance)).to.be.true;
    });

    it('should claim on a daily basis', async () => {
        const amount = BN(1000).mul((1e18).toString());

        await esTap.setBurner(esTapVesting.address);
        await tap.connect(signer).transfer(esTapVesting.address, amount); //FeeDistributor should be the real sender
        await esTap.connect(minter).mintFor(burner.address, amount);
        await esTap.connect(burner).approve(esTapVesting.address, amount);
        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');

        for (let i = 0; i < 120; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        let tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.eq(amount)).to.be.true;
    });

    it('should claim half and then re-invest and continue daily claiming', async () => {
        const amount = BN(1000).mul((1e18).toString());

        await esTap.setBurner(esTapVesting.address);
        await tap.connect(signer).transfer(esTapVesting.address, amount.mul(3)); //FeeDistributor should be the real sender
        await esTap.connect(minter).mintFor(burner.address, amount.mul(3));
        await esTap.connect(burner).approve(esTapVesting.address, amount.mul(3));

        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');
        //claim half
        for (let i = 0; i < 45; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        let tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.lt(BN(550).mul((1e18).toString()))).to.be.true;

        let vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount)).to.be.true;

        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');
        vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount.mul(2))).to.be.true;

        for (let i = 0; i < 120; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.eq(amount.mul(2))).to.be.true;

        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');
        vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount)).to.be.true;
        for (let i = 0; i < 120; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.eq(amount.mul(3))).to.be.true;
    });

    it('should update vesting duration during claiming period', async () => {
        const amount = BN(1000).mul((1e18).toString());

        await esTap.setBurner(esTapVesting.address);
        await tap.connect(signer).transfer(esTapVesting.address, amount); //FeeDistributor should be the real sender
        await esTap.connect(minter).mintFor(burner.address, amount);
        await esTap.connect(burner).approve(esTapVesting.address, amount);
        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');

        for (let i = 0; i < 45; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        let tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.lt(BN(550).mul((1e18).toString()))).to.be.true;

        await esTapVesting.updateVestingDuration(180 * 86400);

        for (let i = 0; i < 200; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.eq(amount)).to.be.true;
    });

    it('should claim half and then re-invest and continue daily claiming while updating the vesting period', async () => {
        const amount = BN(1000).mul((1e18).toString());

        await esTap.setBurner(esTapVesting.address);
        await tap.connect(signer).transfer(esTapVesting.address, amount.mul(3)); //FeeDistributor should be the real sender
        await esTap.connect(minter).mintFor(burner.address, amount.mul(3));
        await esTap.connect(burner).approve(esTapVesting.address, amount.mul(3));

        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');
        //claim half
        for (let i = 0; i < 45; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        let tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.lt(BN(550).mul((1e18).toString()))).to.be.true;

        let vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount)).to.be.true;

        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');
        vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount.mul(2))).to.be.true;

        await esTapVesting.updateVestingDuration(180 * 86400);

        for (let i = 0; i < 120; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.eq(amount.mul(2))).to.be.true;

        await expect(esTapVesting.connect(burner).vest(amount)).to.emit(esTapVesting, 'Vested');
        vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount)).to.be.true;
        for (let i = 0; i < 200; i++) {
            time_travel(86400);
            await esTapVesting.connect(burner).claim();
        }
        tapBalance = await tap.balanceOf(burner.address);
        expect(tapBalance.eq(amount.mul(3))).to.be.true;
    });

    it('should set pause', async () => {
        let paused = await esTapVesting.paused();
        expect(paused).to.be.false;

        await expect(esTapVesting.connect(minter).setPaused(true)).to.be.reverted;
        await expect(esTapVesting.setPaused(true)).to.emit(esTapVesting, 'PauseChanged');

        paused = await esTapVesting.paused();
        expect(paused).to.be.true;
    });

    it('should reset burnable', async () => {
        await expect(esTapVesting.connect(minter).resetBurnable()).to.be.reverted;

        await esTapVesting.resetBurnable();
    });

    it('should emergency withdraw unused tap', async () => {
        const halfAmount = BN(500).mul((1e18).toString());
        const amount = BN(1000).mul((1e18).toString());

        await expect(esTapVesting.connect(minter).emergencyTapWithdraw(true)).to.be.reverted;
        await expect(esTapVesting.emergencyTapWithdraw(true)).to.be.revertedWith('unauthorized');

        await esTapVesting.setPaused(true);
        await expect(esTapVesting.emergencyTapWithdraw(true)).not.to.be.reverted;

        await esTap.connect(minter).mintFor(signer.address, halfAmount);
        await expect(esTapVesting.vest(halfAmount)).to.be.revertedWith('paused');
        await esTapVesting.setPaused(false);
        await esTap.approve(esTapVesting.address, halfAmount);
        await expect(esTapVesting.vest(halfAmount)).to.emit(esTapVesting, 'Vested');

        await tap.transfer(esTapVesting.address, amount);
        await esTapVesting.setPaused(true);

        const tapBalanceBefore = await tap.balanceOf(signer.address);
        await expect(esTapVesting.emergencyTapWithdraw(true)).to.emit(esTapVesting, 'EmergencyTapWithdrawal');
        const tapBalanceAfter = await tap.balanceOf(signer.address);

        expect(halfAmount.eq(tapBalanceAfter.sub(tapBalanceBefore))).to.be.true;
    });

    it('should try to emergency withdraw when all tap is used', async () => {
        const amount = BN(1000).mul((1e18).toString());

        await expect(esTapVesting.connect(minter).emergencyTapWithdraw(true)).to.be.reverted;
        await expect(esTapVesting.emergencyTapWithdraw(true)).to.be.revertedWith('unauthorized');

        await esTapVesting.setPaused(true);
        await expect(esTapVesting.emergencyTapWithdraw(true)).not.to.be.reverted;

        await esTap.connect(minter).mintFor(signer.address, amount);
        await expect(esTapVesting.vest(amount)).to.be.revertedWith('paused');
        await esTapVesting.setPaused(false);
        await esTap.approve(esTapVesting.address, amount);
        await expect(esTapVesting.vest(amount)).to.emit(esTapVesting, 'Vested');

        await tap.transfer(esTapVesting.address, amount);
        await esTapVesting.setPaused(true);

        const tapBalanceBefore = await tap.balanceOf(signer.address);
        await expect(esTapVesting.emergencyTapWithdraw(true)).to.not.be.reverted;
        const tapBalanceAfter = await tap.balanceOf(signer.address);

        expect(tapBalanceAfter.sub(tapBalanceBefore).eq(0)).to.be.true;
    });

    it('should emergency withdraw all tap', async () => {
        const halfAmount = BN(500).mul((1e18).toString());
        const amount = BN(1000).mul((1e18).toString());

        await expect(esTapVesting.connect(minter).emergencyTapWithdraw(true)).to.be.reverted;
        await expect(esTapVesting.emergencyTapWithdraw(true)).to.be.revertedWith('unauthorized');

        await esTapVesting.setPaused(true);
        await expect(esTapVesting.emergencyTapWithdraw(true)).not.to.be.reverted;
        await esTapVesting.setPaused(false);

        await esTap.connect(minter).mintFor(signer.address, halfAmount);
        await esTap.approve(esTapVesting.address, halfAmount);
        await expect(esTapVesting.vest(halfAmount)).to.emit(esTapVesting, 'Vested');

        await tap.transfer(esTapVesting.address, amount);
        await esTapVesting.setPaused(true);

        const tapBalanceBefore = await tap.balanceOf(signer.address);
        await expect(esTapVesting.emergencyTapWithdraw(false)).to.emit(esTapVesting, 'EmergencyTapWithdrawal');
        const tapBalanceAfter = await tap.balanceOf(signer.address);

        expect(amount.eq(tapBalanceAfter.sub(tapBalanceBefore))).to.be.true;
    });

    it('should vest for another user', async () => {
        const amount = BN(1000).mul((1e18).toString());

        let esTapBalance = await esTap.balanceOf(burner.address);
        expect(esTapBalance.eq(0)).to.be.true;

        //blacklist
        await esTapVesting.connect(signer).blacklistUpdate(burner.address, true);
        await expect(esTapVesting.connect(minter).vestFor(amount, burner.address)).to.be.revertedWith('receiver is blacklisted');
        await esTapVesting.connect(signer).blacklistUpdate(burner.address, false);
        await esTapVesting.connect(signer).blacklistUpdate(minter.address, true);
        await expect(esTapVesting.connect(minter).vestFor(amount, burner.address)).to.be.revertedWith('sender is blacklisted');
        await esTapVesting.connect(signer).blacklistUpdate(minter.address, false);

        await expect(esTapVesting.connect(minter).vestFor(amount, burner.address)).to.be.reverted;

        //get esTap
        await esTap.connect(minter).mintFor(minter.address, amount); //FeeDistributor should be the real minter
        esTapBalance = await esTap.balanceOf(minter.address);
        expect(esTapBalance.eq(amount)).to.be.true;

        //vest
        await expect(esTapVesting.connect(minter).vestFor(amount, burner.address)).to.be.reverted;
        await esTap.connect(minter).approve(esTapVesting.address, amount);
        await expect(esTapVesting.connect(minter).vestFor(amount, burner.address)).to.emit(esTapVesting, 'Vested');
        esTapBalance = await esTap.balanceOf(burner.address);
        expect(esTapBalance.eq(0)).to.be.true;

        let vestingData = await esTapVesting.getVesting(burner.address);
        expect(vestingData[3].eq(amount)).to.be.true;
    });
});
