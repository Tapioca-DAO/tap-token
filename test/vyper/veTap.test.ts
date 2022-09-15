import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock, LZEndpointMock, TapOFT } from '../../typechain/';
import { VeTap } from '../../typechain/contracts/vyper/VeTap.vy';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

import { deployLZEndpointMock, deployTapiocaOFT, deployveTapiocaNFT, BN, time_travel } from '../test.utils';

describe('veTapioca', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let signer3: SignerWithAddress;
    let LZEndpointMock: LZEndpointMock;
    let erc20Mock: ERC20Mock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;

    const veTapiocaName = 'veTapioca Token';
    const veTapiocaSymbol = 'veTAP';
    const veTapiocaVersion = '1';
    const DAY: number = 86400;
    const HALF_UNLOCK_TIME: number = 2 * 365 * DAY; //half of max time
    const UNLOCK_TIME: number = 2 * HALF_UNLOCK_TIME; //max time

    async function register() {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        signer3 = (await ethers.getSigners())[2];
        const chainId = (await ethers.provider.getNetwork()).chainId;
        LZEndpointMock = (await deployLZEndpointMock(chainId)) as LZEndpointMock;
        erc20Mock = (await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9))) as ERC20Mock;
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, veTapiocaName, veTapiocaSymbol, veTapiocaVersion)) as VeTap;
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should check initial state', async () => {
        const savedAdmin = await veTapioca.admin();
        expect(savedAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        const savedToken = await veTapioca.token();
        expect(savedToken.toLowerCase()).to.eq(tapiocaOFT.address.toLowerCase());

        const savedController = await veTapioca.controller();
        expect(savedController.toLowerCase()).to.eq(signer.address.toLowerCase());

        const tokenDecimals = await tapiocaOFT.decimals();
        const savedDecimals = await veTapioca.decimals();
        expect(savedDecimals).to.eq(tokenDecimals);

        const savedName = await veTapioca.name();
        expect(savedName).to.eq(veTapiocaName);

        const savedSymbol = await veTapioca.symbol();
        expect(savedSymbol).to.eq(veTapiocaSymbol);

        const savedVersion = await veTapioca.version();
        expect(savedVersion).to.eq(veTapiocaVersion);

        const transferedEnabled = await veTapioca.transfersEnabled();
        expect(transferedEnabled).to.be.true;
    });

    it('should whitelist a contract', async () => {
        const isWhitelisted = await veTapioca.whitelisted_contracts(signer2.address);
        expect(isWhitelisted).to.be.false;

        await veTapioca.whitelist_contract(signer2.address);

        const isNowWhitelisted = await veTapioca.whitelisted_contracts(signer2.address);
        expect(isNowWhitelisted).to.be.true;

        await veTapioca.remove_whitelisted_contract(signer2.address);
        const finalWhitelistStatus = await veTapioca.whitelisted_contracts(signer2.address);
        expect(finalWhitelistStatus).to.be.false;
    });

    it('should change admin', async () => {
        const savedAdmin = await veTapioca.admin();
        expect(savedAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        const savedFutureAdmin = await veTapioca.future_admin();
        expect(savedFutureAdmin.toLowerCase()).to.eq(ethers.constants.AddressZero.toLowerCase());
        await veTapioca.commit_transfer_ownership(signer2.address);

        const newFutureAdmin = await veTapioca.future_admin();
        expect(newFutureAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());

        const stillTheSameAdmin = await veTapioca.admin();
        expect(stillTheSameAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        await veTapioca.apply_transfer_ownership();

        const finalAdmin = await veTapioca.admin();
        expect(finalAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());
    });

    it('should return nothing for non-participant', async () => {
        const lastSlope = await veTapioca.get_last_user_slope(signer.address);
        expect(lastSlope).to.eq(0);

        const lastTimestmap = await veTapioca.user_point_history__ts(signer.address, 0);
        expect(lastTimestmap).to.eq(0);

        // locked__end
        const lockedEnd = await veTapioca.locked__end(signer.address);
        expect(lockedEnd).to.eq(0);

        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        const balanceOf = await erc20.balanceOf(signer.address);
        expect(balanceOf).to.eq(0);

        const balanceOfAt = await veTapioca.balanceOfAt(signer.address, 1);
        expect(balanceOfAt).to.eq(0);

        const totalSupply = await erc20.totalSupply();
        expect(totalSupply).to.eq(0);

        const totalSupplyAt = await veTapioca.totalSupplyAt(1);
        expect(totalSupplyAt).to.eq(0);
    });

    it('should not be able to deposit if no lock was created before', async () => {
        await expect(veTapioca.connect(signer).deposit_for(signer.address, 0)).to.be.revertedWith('value not valid');

        await expect(veTapioca.connect(signer).deposit_for(signer.address, ethers.utils.parseEther('10'))).to.be.revertedWith(
            'locked amount not valid',
        );
    });

    it('should not be able to create lock with invalid params', async () => {
        await expect(veTapioca.connect(signer).create_lock(0, 0)).to.be.revertedWith;
        await expect(veTapioca.connect(signer).create_lock(ethers.utils.parseEther('10'), 0)).to.be.reverted;
        await expect(veTapioca.connect(signer).create_lock(ethers.utils.parseEther('10'), 99999999999999)).to.be.reverted;
    });

    it('should be able to create a lock with TAP', async () => {
        const amountToLock = BN(10000).mul((1e18).toString());
        const minLockedAmount = BN(9000).mul((1e18).toString());

        const latestBlock = await ethers.provider.getBlock('latest');

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + UNLOCK_TIME);

        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        const signerVotingBalance = await erc20.balanceOf(signer.address);
        expect(signerVotingBalance.gt(minLockedAmount)).to.be.true;
    });

    it('should be able to create a lock and voting power should decrease over time', async () => {
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        const signerBalanceOfTAP = await tapiocaOFT.balanceOf(signer.address);
        expect(signerBalanceOfTAP.gt(0)).to.be.true;

        //lock from signer2
        await expect(veTapioca.connect(signer2).create_lock(amountToLock, latestBlock.timestamp + UNLOCK_TIME)).to.be.reverted; // should be reverted as signer2 does not have any tokens yet

        await tapiocaOFT.connect(signer).transfer(signer2.address, amountToLock);
        const signer2BalanceOfTAP = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2BalanceOfTAP.eq(amountToLock)).to.be.true;

        await expect(veTapioca.connect(signer2).create_lock(amountToLock, latestBlock.timestamp + UNLOCK_TIME)).to.be.reverted; //should still revert as there is no approval for spending

        await tapiocaOFT.connect(signer2).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer2).create_lock(amountToLock, latestBlock.timestamp + UNLOCK_TIME);
        const signer2VeTapBalance = await erc20.balanceOf(signer2.address);

        //time tranvel 10 days
        await time_travel(10 * DAY);

        //lock from signer
        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + HALF_UNLOCK_TIME);
        const signerVeTapValance = await erc20.balanceOf(signer.address);

        expect(signer2VeTapBalance.gt(signerVeTapValance)).to.be.true;

        const signerLockedEnd = await veTapioca.locked__end(signer.address);
        const signer2LockedEnd = await veTapioca.locked__end(signer2.address);

        expect(signer2LockedEnd.gt(signerLockedEnd)).to.be.true;

        //time tranvel 100 days
        await time_travel(100 * DAY);

        await veTapioca.checkpoint();
        const signerVotingPower = await veTapioca.get_last_user_slope(signer.address);
        const signer2VotingPower = await veTapioca.get_last_user_slope(signer2.address);
        const finalSignerVeTapBalance = await erc20.balanceOf(signer.address);
        expect(signerVotingPower.gt(0)).to.be.true;
        expect(signer2VotingPower.gt(0)).to.be.true;
        expect(signerVeTapValance.gt(finalSignerVeTapBalance)).to.be.true;
    });

    it('should increase unlock time for position', async () => {
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + HALF_UNLOCK_TIME);

        const signerVeTapBalance = await erc20.balanceOf(signer.address);
        const signerLockedEnd = await veTapioca.locked__end(signer.address);

        // increase_unlock_time
        await veTapioca.connect(signer).increase_unlock_time(latestBlock.timestamp + UNLOCK_TIME);
        const signerNewLockedEnd = await veTapioca.locked__end(signer.address);
        expect(signerNewLockedEnd.gt(signerLockedEnd)).to.be.true;

        const signerVeTapBalanceAfterUnlockTimeIncrease = await erc20.balanceOf(signer.address);
        expect(signerVeTapBalanceAfterUnlockTimeIncrease.gt(signerVeTapBalance)).to.be.true;
    });

    it('should increase amount for position', async () => {
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + HALF_UNLOCK_TIME);
        const signerVeTapBalance = await erc20.balanceOf(signer.address);

        // increase_amount
        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).increase_amount(amountToLock);
        const signerVeTapBalanceAfterAmountIncrease = await erc20.balanceOf(signer.address);

        expect(signerVeTapBalanceAfterAmountIncrease.gt(signerVeTapBalance)).to.be.true;
    });

    it('should create a lock for someone else', async () => {
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock_for(signer2.address, amountToLock, latestBlock.timestamp + UNLOCK_TIME);

        const signer2VeTapBalance = await erc20.balanceOf(signer2.address);
        expect(signer2VeTapBalance.gt(0)).to.be.true;

        const signerVeTokenBalance = await erc20.balanceOf(signer.address);
        expect(signerVeTokenBalance.eq(0)).to.be.true;
    });

    it('should not be able to withdraw', async () => {
        const amountToLock = BN(10000).mul((1e18).toString());
        const finalPossibleAmount = BN(2500).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + UNLOCK_TIME);

        const signerVeTapBalance = await erc20.balanceOf(signer.address);

        //should revert
        await expect(veTapioca.connect(signer).withdraw()).to.be.reverted;

        //make sure the unlock time has passed
        await time_travel(10 * UNLOCK_TIME);

        await veTapioca.connect(signer).withdraw();

        const signerFinalVeTapBalance = await erc20.balanceOf(signer.address);

        expect(signerFinalVeTapBalance.lt(signerVeTapBalance)).to.be.true;
        expect(signerFinalVeTapBalance.eq(0)).to.be.true;
    });

    it('should be able to force withdraw with a penaly', async () => {
        const amountToLock = BN(10000).mul((1e18).toString());
        const finalPossibleAmount = BN(2500).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        await veTapioca.set_penalty_receiver(signer3.address);

        await tapiocaOFT.connect(signer).transfer(signer2.address, amountToLock);
        await tapiocaOFT.connect(signer2).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer2).create_lock(amountToLock, latestBlock.timestamp + UNLOCK_TIME);

        let singer3TapBalance = await tapiocaOFT.balanceOf(signer3.address);
        expect(singer3TapBalance.eq(0)).to.be.true;

        const signer2VeTapBalance = await erc20.balanceOf(signer2.address);
        expect(signer2VeTapBalance.gt(0)).to.be.true;

        await expect(veTapioca.connect(signer3).force_withdraw()).to.be.reverted; //not a valid user
        await veTapioca.connect(signer2).force_withdraw();

        singer3TapBalance = await tapiocaOFT.balanceOf(signer3.address);
        expect(singer3TapBalance.gt(0)).to.be.true;

        const signer2FinalTapBalance = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2FinalTapBalance.eq(finalPossibleAmount)).to.be.true;
    });
});
