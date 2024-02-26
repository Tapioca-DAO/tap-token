import { ethers } from 'hardhat';
import { expect } from 'chai';
import {
    registerVesting,
    time_travel,
    randomSigners,
    deployUSDC,
    BN,
} from './test.utils';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock } from '@tapioca-sdk/typechain/tapioca-mocks';

describe('Vesting', () => {
    let usdc: ERC20Mock;
    let deployer: SignerWithAddress;
    let eoa1: SignerWithAddress;

    async function register() {
        deployer = (await ethers.getSigners())[0];
        eoa1 = (await ethers.getSigners())[1];
        usdc = (await deployUSDC(
            ethers.utils.parseEther('100000000'),
            18,
            deployer,
        )) as ERC20Mock;
    }
    beforeEach(async () => {
        await loadFixture(register);
    });

    describe('init', () => {
        it('should test init without initial unlock', async () => {
            const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(
                1000,
            );
            await usdc.freeMint(mintAmount);

            const cliff = 86400 * 10;
            const duration = 86400 * 100;
            const { vesting } = await registerVesting(
                usdc.address,
                cliff,
                duration,
                deployer.address,
            );

            await usdc.transfer(vesting.address, mintAmount);

            await expect(
                vesting.connect(eoa1).init(usdc.address, mintAmount, 0),
            ).to.be.reverted;
            await expect(
                vesting.init(usdc.address, 0, 0),
            ).to.be.revertedWithCustomError(vesting, 'NoTokens');

            await vesting.init(usdc.address, mintAmount, 0);
            const start = (await ethers.provider.getBlock('latest')).timestamp;

            await expect(
                vesting.init(usdc.address, mintAmount, 0),
            ).to.be.revertedWithCustomError(vesting, 'Initialized');

            expect((await vesting.start()).gt(0)).to.be.true;
            expect(await vesting.cliff()).to.be.eq(cliff);
            expect(await vesting.duration()).to.be.eq(duration);
            expect(await vesting['vested()']()).to.be.eq(0);
            expect(await vesting['claimable()']()).to.be.eq(0);

            await time_travel(cliff / 2);
            expect(await vesting['vested()']()).to.be.eq(0);

            await time_travel(cliff / 2);
            let vestedAfterCliff = await vesting['vested()']();
            expect(vestedAfterCliff).to.be.gt(BN(0));

            const timeForAmount = await vesting
                .computeTimeFromAmount(
                    start,
                    mintAmount,
                    mintAmount.mul(10).div(100),
                    duration,
                )
                .then((res) => res.toNumber());

            await time_travel(duration - cliff - timeForAmount); // ~80% (100% duration - 10% cliff - 10% timeForAmount )
            vestedAfterCliff = await vesting['vested()']();
            expect(vestedAfterCliff).to.be.approximately(
                mintAmount.mul(80).div(100),
                mintAmount.mul(80).div(100).mul(999).div(1000), // 0.1% error
            );
        });

        it('should test init with initial unlock', async () => {
            const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(
                1000,
            );
            const initialUnlock = mintAmount.mul(8).div(100); // 8%
            await usdc.freeMint(mintAmount);

            const cliff = 86400 * 10;
            const duration = 86400 * 100;
            const { vesting } = await registerVesting(
                usdc.address,
                cliff,
                duration,
                deployer.address,
            );
            await usdc.transfer(vesting.address, mintAmount);

            await vesting.init(usdc.address, mintAmount, 800); // 8% unlocked

            expect((await vesting.start()).gt(0)).to.be.true;
            expect(await vesting.cliff()).to.be.eq(cliff);
            expect(await vesting.duration()).to.be.eq(duration);
            expect(await vesting['vested()']()).to.be.eq(0);
            expect(await vesting['claimable()']()).to.be.eq(0);

            await time_travel(cliff / 2);
            expect(await vesting['vested()']()).to.be.eq(0);

            await time_travel(cliff / 2);
            let vestedAfterCliff = await vesting['vested()']();
            expect(vestedAfterCliff).to.be.gte(initialUnlock);

            await time_travel(duration - cliff - cliff / 2); // ~85% (100% duration - 10% cliff - 5% half cliff )
            vestedAfterCliff = await vesting['vested()']();
            expect(vestedAfterCliff).to.be.approximately(
                mintAmount.mul(85).div(100),
                mintAmount.mul(85).div(100).mul(999).div(1000), // 0.1% error
            );
        });
    });

    describe('register', () => {
        it('should register users', async () => {
            const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(
                1000,
            );
            await usdc.freeMint(mintAmount);

            const cliff = 86400 * 10;
            const duration = 86400 * 100;
            const { vesting } = await registerVesting(
                usdc.address,
                cliff,
                duration,
                deployer.address,
            );
            await usdc.transfer(vesting.address, mintAmount);

            await vesting.registerUser(eoa1.address, mintAmount.div(10));
            await vesting.registerUser(deployer.address, mintAmount.div(5));
            await expect(
                vesting.registerUser(deployer.address, mintAmount.div(20)),
            ).to.be.revertedWithCustomError(vesting, 'AlreadyRegistered');

            await expect(
                vesting.init(usdc.address, mintAmount.div(100), 0),
            ).to.be.revertedWithCustomError(vesting, 'NotEnough');
            await vesting.init(usdc.address, mintAmount, 0);

            await expect(
                vesting.registerUser(eoa1.address, mintAmount.div(5)),
            ).to.be.revertedWithCustomError(vesting, 'Initialized');

            let userInfo = await vesting.users(deployer.address);
            expect(userInfo[0].gt(0)).to.be.true;
            userInfo = await vesting.users(eoa1.address);
            expect(userInfo[0].gt(0)).to.be.true;

            const newSigners = await randomSigners(1);
            userInfo = await vesting.users(newSigners[0].address);
            expect(userInfo[0].eq(0)).to.be.true;
        });
    });

    describe('registerUsers', () => {
        it('should bulk register users', async () => {
            const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(
                1000,
            );
            await usdc.freeMint(mintAmount);

            const cliff = 86400 * 10;
            const duration = 86400 * 100;
            const { vesting } = await registerVesting(
                usdc.address,
                cliff,
                duration,
                deployer.address,
            );
            await usdc.transfer(vesting.address, mintAmount);

            await vesting.registerUsers(
                [eoa1.address, deployer.address],
                [mintAmount.div(10), mintAmount.div(5)],
            );

            await expect(
                vesting.registerUsers(
                    [eoa1.address, deployer.address],
                    [mintAmount.div(10), mintAmount.div(5)],
                ),
            ).to.be.revertedWithCustomError(vesting, 'AlreadyRegistered');

            await expect(
                vesting.init(usdc.address, mintAmount.div(100), 0),
            ).to.be.revertedWithCustomError(vesting, 'NotEnough');
            await vesting.init(usdc.address, mintAmount, 0);

            await expect(
                vesting.registerUsers(
                    [eoa1.address, deployer.address],
                    [mintAmount.div(10), mintAmount.div(5)],
                ),
            ).to.be.revertedWithCustomError(vesting, 'Initialized');

            let userInfo = await vesting.users(deployer.address);
            expect(userInfo.amount).to.be.eq(mintAmount.div(5));
            userInfo = await vesting.users(eoa1.address);
            expect(userInfo.amount).to.be.eq(mintAmount.div(10));

            const newSigners = await randomSigners(1);
            userInfo = await vesting.users(newSigners[0].address);
            expect(userInfo.amount).to.be.eq(0);
        });
    });

    describe('claim', () => {
        it('should test claim', async () => {
            const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(
                1000,
            );
            await usdc.freeMint(mintAmount);

            const cliff = 86400 * 10;
            const duration = 86400 * 100;
            const { vesting } = await registerVesting(
                usdc.address,
                cliff,
                duration,
                deployer.address,
            );
            await usdc.transfer(vesting.address, mintAmount);

            const newSigners = await randomSigners(5);

            await vesting.registerUser(eoa1.address, mintAmount.div(4));
            await vesting.registerUser(deployer.address, mintAmount.div(4));
            for (let i = 0; i < newSigners.length; i++) {
                await vesting.registerUser(
                    newSigners[i].address,
                    mintAmount.div(10),
                );
            }

            await vesting.init(usdc.address, mintAmount, 0);
            const totalAmount = await vesting.seeded();
            expect(totalAmount.eq(mintAmount)).to.be.true;

            await time_travel(duration / 2 + cliff); // half the time after cliff, 50% vesting

            const vested = await vesting['vested()']();
            expect(vested).to.be.eq(mintAmount.div(2));

            const randomSignerPossibleAmount = mintAmount.div(20);
            const randomSignerClaimable = await vesting['claimable(address)'](
                newSigners[0].address,
            );

            const eoa1PossibleAmount = mintAmount.div(8);
            const eoa1Claimable = await vesting['claimable(address)'](
                eoa1.address,
            );
            expect(eoa1PossibleAmount.eq(eoa1Claimable)).to.be.true;

            const eoa1TokensBefore = await usdc.balanceOf(eoa1.address);
            await vesting.connect(eoa1).claim();
            const eoa1TokensAfter = await usdc.balanceOf(eoa1.address);
            expect(eoa1TokensAfter.sub(eoa1TokensBefore)).to.be.approximately(
                eoa1Claimable,
                eoa1Claimable.mul(99).div(100),
            );

            const randomSignerTokensBefore = await usdc.balanceOf(
                newSigners[0].address,
            );
            await vesting.connect(newSigners[0]).claim();
            const randomSignerTokensAfter = await usdc.balanceOf(
                newSigners[0].address,
            );
            expect(
                randomSignerTokensAfter.sub(randomSignerTokensBefore),
            ).to.be.approximately(
                randomSignerClaimable,
                randomSignerClaimable.mul(99).div(100),
            );

            await time_travel(duration);

            //claim everything
            await vesting.claim();
            await vesting.connect(eoa1).claim();
            for (let i = 0; i < newSigners.length; i++) {
                await vesting.connect(newSigners[i]).claim();
            }

            let total = await usdc.balanceOf(eoa1.address);
            total = total.add(await usdc.balanceOf(deployer.address));
            for (let i = 0; i < newSigners.length; i++) {
                total = total.add(await usdc.balanceOf(newSigners[i].address));
            }

            expect(total.eq(mintAmount)).to.be.true;

            await time_travel(duration);

            await expect(vesting.claim()).to.be.revertedWithCustomError(
                vesting,
                'NothingToClaim',
            );
            await expect(
                vesting.connect(eoa1).claim(),
            ).to.be.revertedWithCustomError(vesting, 'NothingToClaim');
            for (let i = 0; i < newSigners.length; i++) {
                await expect(
                    vesting.connect(newSigners[i]).claim(),
                ).to.be.revertedWithCustomError(vesting, 'NothingToClaim');
            }
        });
    });

    describe('totals', () => {
        it('should test total vesting', async () => {
            const mintAmount = ethers.BigNumber.from((1e18).toString()).mul(
                1000,
            );
            await usdc.freeMint(mintAmount);

            const cliff = 86400 * 10;
            const duration = 86400 * 100;
            const { vesting } = await registerVesting(
                usdc.address,
                cliff,
                duration,
                deployer.address,
            );
            await usdc.transfer(vesting.address, mintAmount);

            const newSigners = await randomSigners(5);

            await vesting.registerUser(eoa1.address, mintAmount.div(4));
            await vesting.registerUser(deployer.address, mintAmount.div(4));
            for (let i = 0; i < newSigners.length; i++) {
                await vesting.registerUser(
                    newSigners[i].address,
                    mintAmount.div(10),
                );
            }

            await vesting.init(usdc.address, mintAmount, 0);

            const totalAmount = await vesting.seeded();
            expect(totalAmount.eq(mintAmount)).to.be.true;

            await time_travel(duration * 2);

            const totalVesting = await vesting['vested()']();
            const totalClaimable = await vesting['claimable()']();

            expect(totalVesting.eq(totalClaimable)).to.be.true;
            expect(totalVesting.eq(mintAmount)).to.be.true;
        });
    });
});
