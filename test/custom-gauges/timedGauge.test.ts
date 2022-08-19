import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { LZEndpointMock, TapOFT, TimedGauge, ERC20Mock } from '../../typechain';
import writeJsonFile from 'write-json-file';
import { deployLZEndpointMock, deployTapiocaOFT, BN, time_travel, deployTimedGauge } from '../test.utils';
import { BigNumber } from 'ethers';

describe('TimedGauge', () => {
    let signer: SignerWithAddress;
    let user: SignerWithAddress;
    let user2: SignerWithAddress;
    let tapToken: TapOFT;
    let gauge: TimedGauge;
    let erc20Mock: ERC20Mock;
    let erc20Mock2: ERC20Mock;
    let LZEndpointMock: LZEndpointMock;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        user = (await ethers.getSigners())[1];
        user2 = (await ethers.getSigners())[2];
        LZEndpointMock = await deployLZEndpointMock(0);
        tapToken = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        erc20Mock = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9));
        erc20Mock2 = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9));
        gauge = (await deployTimedGauge(erc20Mock.address, tapToken.address)) as TimedGauge;
    });

    it('should check initial state', async () => {
        expect((await gauge.token()).toLocaleLowerCase()).eq(erc20Mock.address.toLocaleLowerCase());
        expect((await gauge.reward()).toLocaleLowerCase()).eq(tapToken.address.toLocaleLowerCase());
        expect((await erc20Mock.balanceOf(gauge.address)).eq(0)).to.be.true;
        expect((await tapToken.balanceOf(gauge.address)).eq(0)).to.be.true;
        expect(await gauge.paused()).to.be.true;

        expect((await gauge.totalSupply()).eq(0)).to.be.true;
        expect((await gauge.balanceOf(signer.address)).eq(0)).to.be.true;

        const rewardsDuration = await gauge.rewardsDuration();
        expect(rewardsDuration.eq(4 * 365 * 86400)).to.be.true;
        const periodFinish = await gauge.periodFinish();
        expect(periodFinish.gt(0)).to.be.true;

        const rewardPerTokenStored = await gauge.rewardPerTokenStored();
        const rewardPerToken = await gauge.rewardPerToken();
        expect(rewardPerToken.eq(rewardPerTokenStored)).to.be.true;

        const earned = await gauge.earned(signer.address);
        expect(earned.eq(0)).to.be.true;

        const rewardForDuration = await gauge.getRewardForDuration();
        expect(rewardForDuration.eq(0)).to.be.true;
    });

    it('should not deploy with wrong parameters', async () => {
        const factory = await ethers.getContractFactory('TimedGauge');
        await expect(factory.deploy(ethers.constants.AddressZero, tapToken.address)).to.be.reverted;
        await expect(factory.deploy(tapToken.address, ethers.constants.AddressZero)).to.be.reverted;
    });

    it('should unpause the contract', async () => {
        expect(await gauge.paused()).to.be.true;
        await expect(gauge.connect(user).unpause()).to.be.reverted;
        await gauge.connect(signer).unpause();
        expect(await gauge.paused()).to.be.false;
        await expect(gauge.connect(user).pause()).to.be.reverted;
        await gauge.connect(signer).pause();
        expect(await gauge.paused()).to.be.true;
    });

    it('should emergency save tokens', async () => {
        const amount = BN(1000).mul((1e18).toString());
        const bigAmount = BN(100000).mul((1e18).toString());

        await expect(gauge.connect(user).emergencySave(erc20Mock2.address, BN(100))).to.be.reverted;
        await expect(gauge.connect(signer).emergencySave(erc20Mock.address, BN(100))).to.be.revertedWith('unauthorized');

        await erc20Mock2.connect(user).freeMint(amount);
        await erc20Mock2.connect(user).transfer(gauge.address, amount);

        await expect(gauge.connect(signer).emergencySave(erc20Mock2.address, 0)).to.be.reverted;
        await expect(gauge.connect(signer).emergencySave(erc20Mock2.address, bigAmount)).to.be.reverted;

        const balanceOfSignerBefore = await erc20Mock2.balanceOf(signer.address);
        await gauge.connect(signer).emergencySave(erc20Mock2.address, amount);
        const balanceOfSignerAfter = await erc20Mock2.balanceOf(signer.address);

        const extracted = balanceOfSignerAfter.sub(balanceOfSignerBefore);
        expect(extracted.eq(amount)).to.be.true;
    });

    it('should update reward duration', async () => {
        await expect(gauge.connect(user).updateRewardDuration(1000 * 365)).to.be.reverted;

        const oldDuration = await gauge.rewardsDuration();
        await gauge.connect(signer).updateRewardDuration(1000 * 365);
        const newDuration = await gauge.rewardsDuration();

        expect(oldDuration.eq(newDuration)).to.be.false;
        expect(newDuration.eq(1000 * 365)).to.be.true;
    });

    it('should add rewards to the contract before period ended', async () => {
        const amount = BN(1000000).mul((1e18).toString());

        await gauge.connect(signer).updateRewardDuration(0);
        await expect(gauge.connect(signer).addRewards(0)).to.be.reverted;
        await gauge.connect(signer).updateRewardDuration(4 * 365 * 86400);

        await expect(gauge.connect(user).addRewards(0)).to.be.reverted;
        await expect(gauge.connect(user).addRewards(0)).to.be.reverted;

        await tapToken.connect(signer).approve(gauge.address, amount);

        const rewardRateBefore = await gauge.rewardRate();
        const lastUpdateTimeBefore = await gauge.lastUpdateTime();
        const periodFinishBefore = await gauge.periodFinish();
        time_travel(10 * 86400);
        await expect(gauge.connect(user).addRewards(amount)).to.be.reverted;
        await expect(gauge.addRewards(amount)).to.emit(gauge, 'RewardAdded');

        const rewardRateAfter = await gauge.rewardRate();
        const lastUpdateTimeAfter = await gauge.lastUpdateTime();
        const periodFinishAfter = await gauge.periodFinish();
        expect(rewardRateAfter.eq(rewardRateBefore)).to.be.false;
        expect(rewardRateAfter.gt(0)).to.be.true;
        expect(lastUpdateTimeAfter.gt(lastUpdateTimeBefore)).to.be.true;
        expect(periodFinishAfter.gt(periodFinishBefore)).to.be.true;
    });

    it('should add rewards to the contract after period ended', async () => {
        const amount = BN(1000000).mul((1e18).toString());
        time_travel(50 * 365 * 86400);
        await tapToken.connect(signer).approve(gauge.address, amount);

        const rewardRateBefore = await gauge.rewardRate();
        const lastUpdateTimeBefore = await gauge.lastUpdateTime();
        const periodFinishBefore = await gauge.periodFinish();
        await expect(gauge.connect(user).addRewards(amount)).to.be.reverted;
        await expect(gauge.addRewards(amount)).to.emit(gauge, 'RewardAdded');

        const rewardRateAfter = await gauge.rewardRate();
        const lastUpdateTimeAfter = await gauge.lastUpdateTime();
        const periodFinishAfter = await gauge.periodFinish();
        expect(rewardRateAfter.eq(rewardRateBefore)).to.be.false;
        expect(rewardRateAfter.gt(0)).to.be.true;
        expect(lastUpdateTimeAfter.gt(lastUpdateTimeBefore)).to.be.true;
        expect(periodFinishAfter.gt(periodFinishBefore)).to.be.true;
    });

    it('should not let the owner renounce ownership', async () => {
        await expect(gauge.connect(signer).renounceOwnership()).to.be.revertedWith('unauthorized');
    });

    it('should allow a deposit', async () => {
        const amount = BN(1000).mul((1e18).toString());

        await erc20Mock.connect(user).freeMint(amount);
        await expect(gauge.connect(user).deposit(amount)).to.be.revertedWith('Pausable: paused');
        await gauge.unpause();
        await expect(gauge.connect(user).deposit(0)).to.be.revertedWith('amount not valid');

        const totalSupplyBefore = await gauge.totalSupply();
        const gaugeBalanceBefore = await gauge.balanceOf(user.address);

        await expect(gauge.connect(user).deposit(amount)).to.be.reverted;
        await erc20Mock.connect(user).approve(gauge.address, amount);
        await expect(gauge.connect(user).deposit(amount)).to.emit(gauge, 'Deposited');

        const totalSupplyAfter = await gauge.totalSupply();
        const gaugeBalanceAfter = await gauge.balanceOf(user.address);

        expect(totalSupplyAfter.gt(totalSupplyBefore)).to.be.true;
        expect(totalSupplyAfter.sub(totalSupplyBefore).eq(amount)).to.be.true;
        expect(gaugeBalanceAfter.eq(amount)).to.be.true;
        expect(gaugeBalanceAfter.gt(gaugeBalanceBefore)).to.be.true;
    });

    it('should allow multiple deposits from the same user', async () => {
        const amount = BN(1000).mul((1e18).toString());

        await erc20Mock.connect(user).freeMint(amount);
        await erc20Mock.connect(user).freeMint(amount);
        await gauge.unpause();

        const totalSupplyBefore = await gauge.totalSupply();
        const gaugeBalanceBefore = await gauge.balanceOf(user.address);

        await erc20Mock.connect(user).approve(gauge.address, amount);
        await expect(gauge.connect(user).deposit(amount)).to.emit(gauge, 'Deposited');

        const totalSupplyAfter = await gauge.totalSupply();
        const gaugeBalanceAfter = await gauge.balanceOf(user.address);
        expect(totalSupplyAfter.gt(totalSupplyBefore)).to.be.true;
        expect(gaugeBalanceAfter.gt(gaugeBalanceBefore)).to.be.true;

        await erc20Mock.connect(user).approve(gauge.address, amount);
        await expect(gauge.connect(user).deposit(amount)).to.emit(gauge, 'Deposited');

        const totalSupplyFinal = await gauge.totalSupply();
        const gaugeBalancefinal = await gauge.balanceOf(user.address);
        expect(totalSupplyFinal.gt(totalSupplyAfter)).to.be.true;
        expect(gaugeBalancefinal.gt(gaugeBalanceAfter)).to.be.true;
    });

    it('should not allow withdrawal', async () => {
        const amount = BN(1000).mul((1e18).toString());
        await expect(gauge.connect(user).withdraw(0)).to.be.reverted;
        await expect(gauge.connect(user).withdraw(amount)).to.be.reverted;
    });

    it('should withdraw', async () => {
        const amount = BN(1000).mul((1e18).toString());
        await erc20Mock.connect(user).freeMint(amount);
        await gauge.unpause();
        await erc20Mock.connect(user).approve(gauge.address, amount);
        await expect(gauge.connect(user).deposit(amount)).to.emit(gauge, 'Deposited');

        const totalSupplyBefore = await gauge.totalSupply();
        const gaugeBalanceBefore = await gauge.balanceOf(user.address);
        await expect(gauge.connect(user).withdraw(amount)).to.emit(gauge, 'Withdrawn');
        const totalSupplyAfter = await gauge.totalSupply();
        const gaugeBalanceAfter = await gauge.balanceOf(user.address);
        expect(totalSupplyAfter.eq(0)).to.be.true;
        expect(totalSupplyAfter.lt(totalSupplyBefore)).to.be.true;
        expect(gaugeBalanceAfter.eq(0)).to.be.true;
        expect(gaugeBalanceAfter.lt(gaugeBalanceBefore)).to.be.true;
    });

    it('should withdraw multiple times', async () => {
        const halfAmount = BN(500).mul((1e18).toString());
        const amount = BN(1000).mul((1e18).toString());

        await gauge.unpause();
        await erc20Mock.connect(user).freeMint(amount);
        await erc20Mock.connect(user).approve(gauge.address, amount);
        await expect(gauge.connect(user).deposit(amount)).to.emit(gauge, 'Deposited');

        await expect(gauge.connect(user).withdraw(halfAmount)).to.emit(gauge, 'Withdrawn');
        await expect(gauge.connect(user).withdraw(halfAmount)).to.emit(gauge, 'Withdrawn');

        const totalSupplyAfter = await gauge.totalSupply();
        const gaugeBalanceAfter = await gauge.balanceOf(user.address);
        expect(totalSupplyAfter.eq(0)).to.be.true;
        expect(gaugeBalanceAfter.eq(0)).to.be.true;
    });

    it('should claim', async () => {
        const amount = BN(1000).mul((1e18).toString());
        await expect(gauge.connect(user).claimRewards()).to.be.reverted;
        await gauge.unpause();
        await expect(gauge.connect(user).claimRewards()).not.to.emit(gauge, 'Claimed');

        await erc20Mock.connect(user).freeMint(amount);
        await erc20Mock.connect(user).approve(gauge.address, amount);
        await expect(gauge.connect(user).deposit(amount)).to.emit(gauge, 'Deposited');

        await tapToken.connect(signer).approve(gauge.address, amount);
        await expect(gauge.addRewards(amount)).to.emit(gauge, 'RewardAdded');

        time_travel(100 * 86400);

        const tapBalanceBefore = await tapToken.balanceOf(user.address);
        await expect(gauge.connect(user).claimRewards()).to.emit(gauge, 'Claimed');
        const tapBalanceAfter = await tapToken.balanceOf(user.address);
        expect(tapBalanceAfter.gt(tapBalanceBefore)).to.be.true;
        expect(tapBalanceAfter.gt(0)).to.be.true;

        time_travel(100 * 86400);
        await expect(gauge.connect(user).claimRewards()).to.emit(gauge, 'Claimed');
        const tapBalanceAfter2ndClaim = await tapToken.balanceOf(user.address);
        expect(tapBalanceAfter2ndClaim.gt(tapBalanceAfter)).to.be.true;

        time_travel(100 * 86400);
        const depositTokenBalanceBefore = await erc20Mock.balanceOf(user.address);
        await expect(gauge.connect(user).withdraw(amount)).to.emit(gauge, 'Withdrawn');
        const depositTokenBalanceAfter = await erc20Mock.balanceOf(user.address);
        expect(depositTokenBalanceAfter.sub(depositTokenBalanceBefore).eq(amount)).to.be.true;

        await expect(gauge.connect(user).claimRewards()).to.emit(gauge, 'Claimed');
        const tapBalanceFinal = await tapToken.balanceOf(user.address);
        expect(tapBalanceFinal.gt(tapBalanceAfter2ndClaim)).to.be.true;
    });

    it('should exit the protocol', async () => {
        const amount = BN(1000).mul((1e18).toString());
        await gauge.unpause();
        await erc20Mock.connect(user).freeMint(amount);
        await erc20Mock.connect(user).approve(gauge.address, amount);
        await expect(gauge.connect(user).deposit(amount)).to.emit(gauge, 'Deposited');
        await tapToken.connect(signer).approve(gauge.address, amount);
        await expect(gauge.addRewards(amount)).to.emit(gauge, 'RewardAdded');

        time_travel(100 * 86400);
        const tapBalanceBefore = await tapToken.balanceOf(user.address);
        const depositTokenBalanceBefore = await erc20Mock.balanceOf(user.address);
        await expect(gauge.connect(user).exit()).to.emit(gauge, 'Withdrawn');
        const depositTokenBalanceAfter = await erc20Mock.balanceOf(user.address);
        expect(depositTokenBalanceAfter.sub(depositTokenBalanceBefore).eq(amount)).to.be.true;
        const tapBalanceFinal = await tapToken.balanceOf(user.address);
        expect(tapBalanceFinal.gt(tapBalanceBefore)).to.be.true;

        const balanceOfUser = await gauge.balanceOf(user.address);
        const totalSupply = await gauge.totalSupply();
        expect(balanceOfUser.eq(0)).to.be.true;
        expect(totalSupply.eq(0)).to.be.true;
    });
});
