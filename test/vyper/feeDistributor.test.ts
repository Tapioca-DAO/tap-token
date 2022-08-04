import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock, LZEndpointMock, FeeDistributor, TapOFT, VeTap } from '../../typechain';

import { deployLZEndpointMock, deployTapiocaOFT, deployveTapiocaNFT, BN, time_travel, deployFeeDistributor } from '../test.utils';
import { BigNumber } from 'ethers';

describe('feeDistributor', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let signer3: SignerWithAddress;
    let LZEndpointMock: LZEndpointMock;
    let erc20Mock: ERC20Mock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let feeDistributor: FeeDistributor;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        signer3 = (await ethers.getSigners())[2];
        const latestBlock = await ethers.provider.getBlock('latest');

        LZEndpointMock = (await deployLZEndpointMock(0)) as LZEndpointMock;
        erc20Mock = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9));
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, 'veTapioca Token', 'veTAP', '1')) as VeTap;
        feeDistributor = (await deployFeeDistributor(
            veTapioca.address,
            latestBlock.timestamp,
            tapiocaOFT.address,
            signer.address,
            signer2.address,
        )) as FeeDistributor;
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should check initial state', async () => {
        const savedStartTime = await feeDistributor.start_time();
        expect(savedStartTime.gt(0)).to.be.true;

        const savedLastTokenTime = await feeDistributor.last_token_time();
        expect(savedLastTokenTime.gt(0)).to.be.true;

        const savedTimeCursor = await feeDistributor.time_cursor();
        expect(savedTimeCursor.gt(0)).to.be.true;

        const savedToken = await feeDistributor.token();
        expect(savedToken.toLowerCase()).to.be.eq(tapiocaOFT.address.toLowerCase());

        const savedAdmin = await feeDistributor.admin();
        expect(savedAdmin.toLowerCase()).to.be.eq(signer.address.toLowerCase());

        const savedEmergencyReturn = await feeDistributor.emergency_return();
        expect(savedEmergencyReturn.toLowerCase()).to.be.eq(signer2.address.toLowerCase());
    });

    it('should transfer ownership', async () => {
        await expect(feeDistributor.connect(signer2).commit_admin(signer2.address)).to.be.reverted;

        await feeDistributor.connect(signer).commit_admin(signer2.address);
        const futureAdmin = await feeDistributor.future_admin();
        expect(futureAdmin.toLowerCase()).to.be.eq(signer2.address.toLowerCase());

        await expect(feeDistributor.connect(signer2).apply_admin()).to.be.reverted;

        await feeDistributor.connect(signer).apply_admin();

        const lastFutureAdmin = await feeDistributor.future_admin();
        expect(lastFutureAdmin.toLowerCase()).to.be.eq(ethers.constants.AddressZero.toLowerCase());

        const lastAdmin = await feeDistributor.admin();
        expect(lastAdmin.toLowerCase()).to.be.eq(signer2.address.toLowerCase());
    });

    it('should kill contract', async () => {
        const killStatus = await feeDistributor.is_killed();
        expect(killStatus).to.be.false;

        await expect(feeDistributor.connect(signer2).kill_me()).to.be.revertedWith('unauthorized');

        await feeDistributor.kill_me();

        const killStatusAfter = await feeDistributor.is_killed();
        expect(killStatusAfter).to.be.true;
    });

    it('should kill contract and transfer remaining tokens', async () => {
        const killStatus = await feeDistributor.is_killed();
        expect(killStatus).to.be.false;
        const depositAmount = BN(20000).mul((1e18).toString());

        await tapiocaOFT.transfer(signer2.address, depositAmount);
        await expect(feeDistributor.connect(signer2).kill_me()).to.be.revertedWith('unauthorized');

        await feeDistributor.kill_me();

        const killStatusAfter = await feeDistributor.is_killed();
        expect(killStatusAfter).to.be.true;

        const balanceOfTAP = await tapiocaOFT.balanceOf(signer2.address);
        expect(balanceOfTAP.gt(0)).to.be.true;
    });

    it('should recover balance', async () => {
        const depositAmount = BN(100000000).mul((1e18).toString());
        await tapiocaOFT.transfer(feeDistributor.address, depositAmount); //normal flow: beachBar.withdrawAllProtocolFees(..)

        const contractTapBalance = await tapiocaOFT.balanceOf(feeDistributor.address);
        const signerTapBalance = await tapiocaOFT.balanceOf(signer.address);
        expect(contractTapBalance.eq(depositAmount)).to.be.true;
        expect(signerTapBalance.eq(0)).to.be.true;

        await expect(feeDistributor.connect(signer2).recover_balance(tapiocaOFT.address)).to.be.revertedWith('unauthorized');
        await expect(feeDistributor.connect(signer).recover_balance(tapiocaOFT.address)).to.be.revertedWith('token not valid');

        const randomToken = await (await ethers.getContractFactory('ERC20Mock')).deploy(depositAmount);
        await randomToken.freeMint(depositAmount);
        await randomToken.transfer(feeDistributor.address, depositAmount);

        const contractRandomTokenBalance = await randomToken.balanceOf(feeDistributor.address);
        const signerRandomTokenBalance = await randomToken.balanceOf(signer.address);
        expect(contractRandomTokenBalance.eq(depositAmount)).to.be.true;
        expect(signerRandomTokenBalance.eq(0)).to.be.true;

        await feeDistributor.connect(signer).recover_balance(randomToken.address);

        const emergencyReturnAddr = await feeDistributor.emergency_return();
        const randomTokenEmergencyAddressBalance = await randomToken.balanceOf(emergencyReturnAddr);
        expect(randomTokenEmergencyAddressBalance.eq(depositAmount)).to.be.true;
    });

    it('should queue new rewards', async () => {
        const depositAmount = BN(100000000).mul((1e18).toString());

        await expect(feeDistributor.connect(signer).queueNewRewards(0)).to.be.revertedWith('amount not valid');

        await tapiocaOFT.connect(signer).approve(feeDistributor.address, depositAmount);
        await feeDistributor.connect(signer).queueNewRewards(depositAmount); //normal flow: beachBar.withdrawAllProtocolFees(..)

        const feeDistributorTapBalance = await tapiocaOFT.balanceOf(feeDistributor.address);
        expect(feeDistributorTapBalance.eq(depositAmount)).to.be.true;
    });

    it('should get ve balance', async () => {
        const unlockTime = 2 * 365 * 86400; //max time
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        time_travel(1 * 86400);

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + unlockTime);

        const balanceOfVeTokens = await erc20.balanceOf(signer.address);
        expect(balanceOfVeTokens.gt(0)).to.be.true;

        time_travel(60 * 86400);
        const crtBlock = await ethers.provider.getBlock('latest');

        const veBalanceReportedByFeeSharing = await feeDistributor.ve_for_at(signer.address, crtBlock.timestamp);
        const maxUserEpoch = await veTapioca.user_point_epoch(signer.address);
        expect(maxUserEpoch.eq(1)).to.be.true;
        expect(veBalanceReportedByFeeSharing.gt(0)).to.be.true;
    });

    it('should claim', async () => {
        const unlockTime = 2 * 365 * 86400; //max time
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const feeDistributorInterface = await ethers.getContractAt('IFeeDistributor', feeDistributor.address);

        await prepareLock(tapiocaOFT, veTapioca, signer2, amountToLock, unlockTime, latestBlock.timestamp);
        time_travel(50 * 86400);

        const crtBlock = await ethers.provider.getBlock('latest');
        const veBalanceReportedByFeeSharing = await feeDistributor.ve_for_at(signer2.address, crtBlock.timestamp);
        expect(veBalanceReportedByFeeSharing.gt(0)).to.be.true;

        await tapiocaOFT.connect(signer).approve(feeDistributor.address, amountToLock);
        await feeDistributor.connect(signer).queueNewRewards(amountToLock); //normal flow: beachBar.withdrawAllProtocolFees(..)

        const feeDistributorBalance = await tapiocaOFT.balanceOf(feeDistributor.address);
        expect(feeDistributorBalance.eq(amountToLock)).to.be.true;

        const signer2TapBalanceBeforeClaim = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceBeforeClaim.eq(0)).to.be.true;

        await feeDistributorInterface.connect(signer2).claim(signer2.address, false);

        const signer2TapBalanceAfterClaim = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceAfterClaim.gt(0)).to.be.true;

        time_travel(50 * 86400);
        await feeDistributorInterface.connect(signer2).claim(signer2.address, false);
        const signer2TapBalanceAfterClaim2 = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceAfterClaim2.gt(signer2TapBalanceAfterClaim)).to.be.true;
    });

    it('should claim when simulating a beachBar call', async () => {
        const unlockTime = 2 * 365 * 86400; //max time
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const feeDistributorInterface = await ethers.getContractAt('IFeeDistributor', feeDistributor.address);

        await prepareLock(tapiocaOFT, veTapioca, signer2, amountToLock, unlockTime, latestBlock.timestamp);

        time_travel(50 * 86400);

        const crtBlock = await ethers.provider.getBlock('latest');
        const veBalanceReportedByFeeSharing = await feeDistributor.ve_for_at(signer2.address, crtBlock.timestamp);
        expect(veBalanceReportedByFeeSharing.gt(0)).to.be.true;

        await tapiocaOFT.connect(signer).approve(feeDistributor.address, amountToLock);
        await tapiocaOFT.connect(signer).transfer(feeDistributor.address, amountToLock); //normal flow: beachBar.withdrawAllProtocolFees(..)

        const feeDistributorBalance = await tapiocaOFT.balanceOf(feeDistributor.address);
        expect(feeDistributorBalance.eq(amountToLock)).to.be.true;

        const signer2TapBalanceBeforeClaim = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceBeforeClaim.eq(0)).to.be.true;

        await feeDistributorInterface.connect(signer2).claim(signer2.address, false);

        const signer2TapBalanceAfterClaim = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceAfterClaim.gt(0)).to.be.true;

        time_travel(50 * 86400);
        await feeDistributorInterface.connect(signer2).claim(signer2.address, false);
        const signer2TapBalanceAfterClaim2 = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceAfterClaim2.gt(signer2TapBalanceAfterClaim)).to.be.true;
    });

    it('should claim many', async () => {
        const unlockTime = 2 * 365 * 86400; //max time
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');

        await prepareLock(tapiocaOFT, veTapioca, signer2, amountToLock, unlockTime, latestBlock.timestamp);
        await prepareLock(tapiocaOFT, veTapioca, signer3, amountToLock, unlockTime, latestBlock.timestamp);

        time_travel(50 * 86400);

        const crtBlock = await ethers.provider.getBlock('latest');
        const signer2VeBalanceReportedByFeeSharing = await feeDistributor.ve_for_at(signer2.address, crtBlock.timestamp);
        const signer3VeBalanceReportedByFeeSharing = await feeDistributor.ve_for_at(signer3.address, crtBlock.timestamp);
        expect(signer2VeBalanceReportedByFeeSharing.gt(0)).to.be.true;
        expect(signer3VeBalanceReportedByFeeSharing.gt(0)).to.be.true;

        await tapiocaOFT.connect(signer).approve(feeDistributor.address, amountToLock);
        await feeDistributor.connect(signer).queueNewRewards(amountToLock); //normal flow: beachBar.withdrawAllProtocolFees(..)

        await feeDistributor.claim_many([
            signer2.address,
            signer2.address,
            signer3.address,
            signer3.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
        ]);

        const signer2TapBalanceAfterClaim = await tapiocaOFT.balanceOf(signer2.address);
        const signer3TapBalanceAfterClaim = await tapiocaOFT.balanceOf(signer3.address);
        expect(signer2TapBalanceAfterClaim.gt(0)).to.be.true;
        expect(signer3TapBalanceAfterClaim.gt(0)).to.be.true;

        time_travel(50 * 86400);

        await feeDistributor.claim_many([
            signer2.address,
            signer2.address,
            signer3.address,
            signer3.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
        ]);

        const signer2TapBalanceAfterClaim2 = await tapiocaOFT.balanceOf(signer2.address);
        const signer3TapBalanceAfterClaim2 = await tapiocaOFT.balanceOf(signer3.address);
        expect(signer2TapBalanceAfterClaim2.gt(signer2TapBalanceAfterClaim)).to.be.true;
        expect(signer3TapBalanceAfterClaim2.gt(signer3TapBalanceAfterClaim)).to.be.true;
    });
});

async function prepareLock(
    tapiocaOFT: TapOFT,
    veTapioca: VeTap,
    signer: SignerWithAddress,
    amountToLock: BigNumber,
    unlockTime: number,
    timestamp: number,
) {
    await tapiocaOFT.transfer(signer.address, amountToLock);
    await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
    await veTapioca.connect(signer).create_lock(amountToLock, timestamp + unlockTime);
}
