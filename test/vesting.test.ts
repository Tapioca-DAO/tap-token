import { ethers } from 'hardhat';
import { expect } from 'chai';
import { registerVesting, time_travel, randomSigners, deployUSDC } from './test.utils';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { ERC20Mock } from '../typechain';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

describe('Vesting', () => {
    let usdc: ERC20Mock;
    let deployer: SignerWithAddress;
    let eoa1: SignerWithAddress;

    async function register() {
        deployer = (await ethers.getSigners())[0];
        eoa1 = (await ethers.getSigners())[1];
        usdc = (await deployUSDC(ethers.utils.parseEther('100000000'), 18)) as ERC20Mock;
    }
    beforeEach(async () => {
        await loadFixture(register);
    });
    it('should test init', async () => {
        const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(1000);
        await usdc.freeMint(mintAmount);

        const cliff = 86400 * 10;
        const duration = 86400 * 100;
        const { vesting } = await registerVesting(usdc.address, cliff, duration);

        await usdc.approve(vesting.address, mintAmount);
        await expect(vesting.connect(eoa1).init(mintAmount)).to.be.revertedWith('Ownable: caller is not the owner');
        await expect(vesting.init(0)).to.be.revertedWith('Vesting: no tokens');

        await vesting.init(mintAmount);
        await expect(vesting.init(mintAmount)).to.be.revertedWith('Vesting: initialized');

        const savedCliff = await vesting.cliff();
        expect(savedCliff.eq(cliff)).to.be.true;

        const savedDuration = await vesting.duration();
        expect(savedDuration.eq(duration)).to.be.true;

        let vested = await vesting['vested()']();
        expect(vested.eq(0)).to.be.true;

        let claimable = await vesting['claimable()']();
        expect(claimable.eq(0)).to.be.true;

        await time_travel(cliff / 2);

        vested = await vesting['vested()']();
        expect(vested.eq(0)).to.be.true;

        await time_travel(cliff);

        let vestedAfterCliff = await vesting['vested()']();
        expect(vestedAfterCliff.gt(0)).to.be.true;
        const prevAmount = vestedAfterCliff;

        await time_travel(cliff);
        vestedAfterCliff = await vesting['vested()']();
        expect(vestedAfterCliff.gt(prevAmount)).to.be.true;

        expect((await vesting.start()).gt(0)).to.be.true;
    });

    it('should register users', async () => {
        const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(1000);
        await usdc.freeMint(mintAmount);

        const cliff = 86400 * 10;
        const duration = 86400 * 100;
        const { vesting } = await registerVesting(usdc.address, cliff, duration);

        await usdc.approve(vesting.address, mintAmount);

        await vesting.registerUser(eoa1.address, mintAmount.div(10));
        await vesting.registerUser(deployer.address, mintAmount.div(5));
        await expect(vesting.registerUser(deployer.address, mintAmount.div(20))).to.be.revertedWith('Vesting: user registered');

        await expect(vesting.init(mintAmount.div(100))).to.be.revertedWith('Vesting: not enough');
        await vesting.init(mintAmount);

        await expect(vesting.registerUser(eoa1.address, mintAmount.div(5))).to.be.revertedWith('Vesting: initialized');

        let userInfo = await vesting.users(deployer.address);
        expect(userInfo[0].gt(0)).to.be.true;
        userInfo = await vesting.users(eoa1.address);
        expect(userInfo[0].gt(0)).to.be.true;

        const newSigners = await randomSigners(1);
        userInfo = await vesting.users(newSigners[0].address);
        expect(userInfo[0].eq(0)).to.be.true;
    });

    it('should test claim', async () => {
        const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(1000);
        await usdc.freeMint(mintAmount);

        const cliff = 86400 * 10;
        const duration = 86400 * 100;
        const { vesting } = await registerVesting(usdc.address, cliff, duration);
        await usdc.approve(vesting.address, mintAmount);
        const newSigners = await randomSigners(5);

        await vesting.registerUser(eoa1.address, mintAmount.div(4));
        await vesting.registerUser(deployer.address, mintAmount.div(4));
        for (var i = 0; i < newSigners.length; i++) {
            await vesting.registerUser(newSigners[i].address, mintAmount.div(10));
        }

        await vesting.init(mintAmount);
        const totalAmount = await vesting.seeded();
        expect(totalAmount.eq(mintAmount)).to.be.true;

        await time_travel(duration / 2);

        let vested = await vesting['vested()']();
        expect(vested.eq(mintAmount.div(2))).to.be.true;

        let randomSignerPossibleAmount = mintAmount.div(20);
        let randomSignerClaimable = await vesting['claimable(address)'](newSigners[0].address);

        let eoa1PossibleAmount = mintAmount.div(8);
        let eoa1Claimable = await vesting['claimable(address)'](eoa1.address);
        expect(eoa1PossibleAmount.eq(eoa1Claimable)).to.be.true;

        let eoa1TokensBefore = await usdc.balanceOf(eoa1.address);
        await vesting.connect(eoa1).claim();
        let eoa1TokensAfter = await usdc.balanceOf(eoa1.address);
        expect(eoa1TokensAfter.sub(eoa1TokensBefore)).to.be.approximately(eoa1Claimable, eoa1Claimable.mul(99).div(100));

        let randomSignerTokensBefore = await usdc.balanceOf(newSigners[0].address);
        await vesting.connect(newSigners[0]).claim();
        let randomSignerTokensAfter = await usdc.balanceOf(newSigners[0].address);
        expect(randomSignerTokensAfter.sub(randomSignerTokensBefore)).to.be.approximately(
            randomSignerClaimable,
            randomSignerClaimable.mul(99).div(100),
        );

        await time_travel(duration);

        //claim everything
        await vesting.claim();
        await vesting.connect(eoa1).claim();
        for (var i = 0; i < newSigners.length; i++) {
            await vesting.connect(newSigners[i]).claim();
        }

        let total = await usdc.balanceOf(eoa1.address);
        total = total.add(await usdc.balanceOf(deployer.address));
        for (var i = 0; i < newSigners.length; i++) {
            total = total.add(await usdc.balanceOf(newSigners[i].address));
        }

        expect(total.eq(mintAmount)).to.be.true;

        await time_travel(duration);

        await expect(vesting.claim()).to.be.revertedWith('Vesting: nothing');
        await expect(vesting.connect(eoa1).claim()).to.be.revertedWith('Vesting: nothing');
        for (var i = 0; i < newSigners.length; i++) {
            await expect(vesting.connect(newSigners[i]).claim()).to.be.revertedWith('Vesting: nothing');
        }
    });

    it('should test total vesting', async () => {
        const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(1000);
        await usdc.freeMint(mintAmount);

        const cliff = 86400 * 10;
        const duration = 86400 * 100;
        const { vesting } = await registerVesting(usdc.address, cliff, duration);
        await usdc.approve(vesting.address, mintAmount);
        const newSigners = await randomSigners(5);

        await vesting.registerUser(eoa1.address, mintAmount.div(4));
        await vesting.registerUser(deployer.address, mintAmount.div(4));
        for (var i = 0; i < newSigners.length; i++) {
            await vesting.registerUser(newSigners[i].address, mintAmount.div(10));
        }

        await vesting.init(mintAmount);

        const totalAmount = await vesting.seeded();
        expect(totalAmount.eq(mintAmount)).to.be.true;

        await time_travel(duration * 2);

        const totalVesting = await vesting['vested()']();
        const totalClaimable = await vesting['claimable()']();

        expect(totalVesting.eq(totalClaimable)).to.be.true;
        expect(totalVesting.eq(mintAmount)).to.be.true;
    });

    it('should test general revoke', async () => {
        const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(1000);
        await usdc.freeMint(mintAmount);

        const cliff = 86400 * 10;
        const duration = 86400 * 100;
        const { vesting } = await registerVesting(usdc.address, cliff, duration);
        await usdc.approve(vesting.address, mintAmount);
        const newSigners = await randomSigners(5);

        await vesting.registerUser(eoa1.address, mintAmount.div(4));
        await vesting.registerUser(deployer.address, mintAmount.div(4));
        for (var i = 0; i < newSigners.length; i++) {
            await vesting.registerUser(newSigners[i].address, mintAmount.div(10));
        }

        await vesting.init(mintAmount);

        await expect(vesting.connect(eoa1)['emergencyRevoke()']()).to.be.reverted;
        await expect(vesting['emergencyRevoke()']()).to.be.revertedWith('Vesting: not requested');

        const vestingBalanceBefore = await usdc.balanceOf(vesting.address);
        expect(vestingBalanceBefore.eq(mintAmount)).to.be.true;

        let requestedAt = await vesting.revokeRequestedAt();
        expect(requestedAt.eq(0)).to.be.true;

        await expect(vesting.connect(eoa1)['requestEmergencyRevoke()']()).to.be.reverted;
        await vesting['requestEmergencyRevoke()']();

        requestedAt = await vesting.revokeRequestedAt();
        expect(requestedAt.gt(0)).to.be.true;

        await expect(vesting['requestEmergencyRevoke()']()).to.be.revertedWith('Vesting: requested');

        await expect(vesting['emergencyRevoke()']()).to.be.revertedWith('Vesting: too early');

        await time_travel(86401);

        await vesting['emergencyRevoke()']();

        const vestingBalanceAfter = await usdc.balanceOf(vesting.address);
        expect(vestingBalanceAfter.eq(0)).to.be.true;
        const ownerUsdcBalance = await usdc.balanceOf(deployer.address);
        expect(ownerUsdcBalance.eq(mintAmount)).to.be.true;

        await expect(vesting['emergencyRevoke()']()).to.be.revertedWith('Vesting: revoked');

        const newRevokedAt = await vesting.revokeRequestedAt();
        expect(newRevokedAt.eq(0)).to.be.true;

        const revokedStatus = await vesting.revoked();
        expect(revokedStatus).to.be.true;
    });

    it('should test user revoke', async () => {
        const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(1000);
        await usdc.freeMint(mintAmount);

        const cliff = 86400 * 10;
        const duration = 86400 * 100;
        const { vesting } = await registerVesting(usdc.address, cliff, duration);
        await usdc.approve(vesting.address, mintAmount);
        const newSigners = await randomSigners(5);

        await vesting.registerUser(eoa1.address, mintAmount.div(4));
        await vesting.registerUser(deployer.address, mintAmount.div(4));
        for (var i = 0; i < newSigners.length; i++) {
            await vesting.registerUser(newSigners[i].address, mintAmount.div(10));
        }

        await vesting.init(mintAmount);

        await time_travel(duration / 2);
        await vesting.connect(eoa1).claim();

        const usdcBalanceBefore = await usdc.balanceOf(deployer.address);
        let userInfoBefore = await vesting.users(eoa1.address);

        const revokedStatusBefore = userInfoBefore[3];
        expect(revokedStatusBefore).to.be.false;
        const claimed = userInfoBefore[1];
        expect(claimed.gt(0)).to.be.true;
        const amount = userInfoBefore[0];
        expect(amount.eq(mintAmount.div(4))).to.be.true;

        let requestedAt = await vesting.revokeRequestedAt();
        expect(requestedAt.eq(0)).to.be.true;

        await expect(vesting.connect(eoa1)['requestEmergencyRevoke(address)'](eoa1.address)).to.be.reverted;
        await vesting['requestEmergencyRevoke(address)'](eoa1.address);

        requestedAt = await vesting.revokeRequestedAt();
        expect(requestedAt.gt(0)).to.be.true;

        await expect(vesting['requestEmergencyRevoke(address)'](eoa1.address)).to.be.revertedWith('Vesting: requested');

        await expect(vesting['emergencyRevoke(address)'](eoa1.address)).to.be.revertedWith('Vesting: too early');

        await time_travel(86401);
        await vesting['emergencyRevoke(address)'](eoa1.address);

        await expect(vesting['emergencyRevoke(address)'](eoa1.address)).to.be.revertedWith('Vesting: revoked');

        const newRevokedAt = await vesting.revokeRequestedAt();
        expect(newRevokedAt.eq(0)).to.be.true;

        userInfoBefore = await vesting.users(eoa1.address);

        const revokedStatusAfter = userInfoBefore[3];
        expect(revokedStatusAfter).to.be.true;
        const claimedAfter = userInfoBefore[1];
        expect(claimedAfter.eq(claimed)).to.be.true;
        const amountAfter = userInfoBefore[0];
        expect(amountAfter.eq(mintAmount.div(4))).to.be.true;
        const usdcBalanceAfter = await usdc.balanceOf(deployer.address);
        expect(usdcBalanceAfter.sub(usdcBalanceBefore).eq(amount.sub(claimed))).to.be.true;

        const signer0BalanceBefore = await usdc.balanceOf(newSigners[0].address);
        await vesting.connect(newSigners[0]).claim();
        const signer0BalanceAfter = await usdc.balanceOf(newSigners[0].address);

        expect(signer0BalanceBefore.eq(0)).to.be.true;
        expect(signer0BalanceAfter.gte(mintAmount.div(21))).to.be.true;
    });

    it('should test pause functionality', async () => {
        const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(1000);
        await usdc.freeMint(mintAmount);

        const cliff = 86400 * 10;
        const duration = 86400 * 100;
        const { vesting } = await registerVesting(usdc.address, cliff, duration);
        await usdc.approve(vesting.address, mintAmount);
        const newSigners = await randomSigners(5);

        await vesting.registerUser(eoa1.address, mintAmount.div(4));
        await vesting.registerUser(deployer.address, mintAmount.div(4));
        for (var i = 0; i < newSigners.length; i++) {
            await vesting.registerUser(newSigners[i].address, mintAmount.div(10));
        }

        await vesting.init(mintAmount);

        let pauseState = await vesting.paused();
        expect(pauseState).to.be.false;

        await expect(vesting.connect(eoa1).updatePause(true)).to.be.revertedWith('Vesting: unauthorized');
        await vesting.updatePause(true);
        pauseState = await vesting.paused();
        expect(pauseState).to.be.true;

        await expect(vesting.connect(eoa1).claim()).to.be.revertedWith(`Vesting: paused`);
    });
});
