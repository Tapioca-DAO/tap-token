import {
    loadFixture,
    takeSnapshot,
    time,
} from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre from 'hardhat';
import {
    BN,
    aml_computeAverageMagnitude,
    aml_computeTarget,
    aml_computeMagnitude,
    getERC721PermitSignature,
    time_travel,
} from '../test.utils';
import { AOTAP, AirdropBroker, TapOFT } from '../../typechain';
import { BigNumber, BigNumberish, BytesLike } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { setupFixture } from './fixture.aoTAP';

describe.only('AirdropBroker', () => {
    const setupEnv = async (adb: AirdropBroker, tapOFT: TapOFT) => {
        await adb.aoTAPBrokerClaim();
        await tapOFT.setMinter(adb.address);
    };
    const newEpoch = async (adb: AirdropBroker) => {
        await time_travel((await adb.EPOCH_DURATION()).toNumber());
        await adb.newEpoch();
    };
    const adbParticipate = async (
        signer: SignerWithAddress,
        data: BytesLike,
        adb: AirdropBroker,
        aoTAP: AOTAP,
    ) => {
        await adb.connect(signer).participate(data);

        const aoTAPTokenID = await aoTAP.mintedAOTAP();
        const aoTAPOption = await aoTAP.options(aoTAPTokenID);

        return {
            aoTAPTokenID,
            aoTAPOption,
        };
    };

    it('should claim oTAP and TAP', async () => {
        const { adb, aoTAP, tapOFT } = await loadFixture(setupFixture);

        await adb.aoTAPBrokerClaim();
        expect(await aoTAP.broker()).to.be.eq(adb.address);

        await tapOFT.setMinter(adb.address);
        expect(await tapOFT.minter()).to.be.eq(adb.address);
    });

    it('should check initial values', async () => {
        const { adb, tapOFT, aoTAP } = await loadFixture(setupFixture);

        // ---- Setup adb
        await adb.aoTAPBrokerClaim();
        expect(await aoTAP.broker()).to.be.eq(adb.address);

        await tapOFT.setMinter(adb.address);
        expect(await tapOFT.minter()).to.be.eq(adb.address);

        // ---- Check initial values

        // Epoch related
        expect(adb.epochTAPValuation()).to.be.eq(BN(0));
        expect(adb.lastEpochUpdate()).to.be.eq(BN(0));
        expect(adb.epoch()).to.be.eq(BN(0));

        // Phase 1
        expect(adb.PHASE_1_DISCOUNT()).to.be.eq(BN(50 * 1e4));

        // Phase2
        expect(adb.phase2MerkleRoots(0)).to.be.eq(BN(0));
        expect(adb.PHASE_2_AMOUNT_PER_USER(0)).to.be.eq(BN(200));
        expect(adb.PHASE_2_AMOUNT_PER_USER(1)).to.be.eq(BN(190));
        expect(adb.PHASE_2_AMOUNT_PER_USER(2)).to.be.eq(BN(200));
        expect(adb.PHASE_2_AMOUNT_PER_USER(3)).to.be.eq(BN(190));

        // Phase3
        expect(adb.PHASE_3_AMOUNT_PER_USER()).to.be.eq(BN(714));
        expect(adb.PHASE_3_DISCOUNT()).to.be.eq(BN(50 * 1e4));

        // Phase4
        expect(adb.PHASE_4_DISCOUNT()).to.be.eq(BN(33 * 1e4));

        expect(adb.EPOCH_DURATION()).to.be.eq(BN(2 * 24 * 60 * 60)); // 2 days
    });

    describe.only('Phase 1', () => {
        it('Should register users', async () => {
            const {
                signer,
                users: [rndSigner],
                adb,
                generatePhase1_4Signers,
            } = await loadFixture(setupFixture);
            const users = await generatePhase1_4Signers(100);
            await expect(
                adb
                    .connect(rndSigner)
                    .registerUserForPhase(
                        1,
                        [users[0].wallet.address],
                        [users[0].amount],
                    ),
            ).to.be.revertedWith('Ownable: caller is not the owner');

            await adb.registerUserForPhase(
                1,
                users.map((e) => e.wallet.address),
                users.map((e) => e.amount),
            );

            for (const user of users) {
                expect(await adb.phase1Users(user.wallet.address)).to.be.eq(
                    user.amount,
                );
            }
        });

        it('Should participate', async () => {
            const {
                signer,
                users: [rndSigner],
                adb,
                tapOFT,
                aoTAP,
                generatePhase1_4Signers,
            } = await loadFixture(setupFixture);
            setupEnv(adb, tapOFT);

            // Gen users and register them
            const users = await generatePhase1_4Signers(100);
            await adb.registerUserForPhase(
                1,
                users.map((e) => e.wallet.address),
                users.map((e) => e.amount),
            );
            await adb.registerUserForPhase(
                4,
                users.map((e) => e.wallet.address),
                users.map((e) => e.amount),
            );

            //---- Can't participate if epoch is not started or finished
            await expect(
                adb.connect(users[0].wallet).participate('0x00'),
            ).to.be.revertedWith('adb: Airdrop not started');

            // Get snapshot and go to epoch 5, which is incorrect
            const snapshot = await takeSnapshot();
            for (let i = 0; i < 5; i++) {
                await newEpoch(adb);
            }
            await expect(
                adb.connect(users[0].wallet).participate('0x00'),
            ).to.be.revertedWith('adb: Airdrop ended');
            await snapshot.restore();

            //---- test adb participation
            await newEpoch(adb);
            expect(await adb.epoch()).to.be.eq(BN(1));

            for (const user of users) {
                const mintedOTAP = await aoTAP.mintedAOTAP();
                // Participate
                await expect(
                    adb.connect(user.wallet).participate(user.wallet.address),
                )
                    .to.emit(adb, 'Participate')
                    .withArgs(1, mintedOTAP);

                // Get aoTAP tokenID and check aoTAP option
                const aoTAPTokenID = mintedOTAP.add(1);
                const aoTAPOption = await aoTAP.options(aoTAPTokenID);

                // Validate aoTAP option
                expect(aoTAPOption.amount).to.be.eq(user.amount); // Entitled amount
                expect(aoTAPOption.expiry).to.be.eq(
                    (await adb.lastEpochUpdate()).add(
                        await adb.EPOCH_DURATION(),
                    ),
                ); // Expiry 2 days after epoch start
                expect(aoTAPOption.discount).to.be.eq(BN(50e4)); // 50% discount

                // Close eligibility
                expect(await adb.phase1Users(user.wallet.address)).to.be.eq(0);
                await expect(
                    adb.connect(user.wallet).participate(user.wallet.address),
                ).to.revertedWith('adb: Not eligible');
            }
        });
    });

    it('should participate', async () => {
        const { signer, users, adb, tapOFT } = await loadFixture(setupFixture);

        // Setup adb
        await setupEnv(adb, tapOFT);

        // test adb participation
        await expect(adb.participate(29)).to.be.revertedWith(
            'adb: Position is not active',
        ); // invalid/inexistent tokenID
        await expect(
            adb.connect(users[0]).participate(tokenID),
        ).to.be.revertedWith('adb: Not approved or owner'); // Not owner

        const prevPoolState = await adb.twAML(sglTokenMockAsset);

        await tOLP.approve(adb.address, tokenID);
        await adb.participate(tokenID);
        const participation = await adb.participants(tokenID);

        // Check participation
        const computedAML = {
            magnitude: BN(0),
            averageMagnitude: BN(0),
            discount: BN(0),
        };
        computedAML.magnitude = aml_computeMagnitude(BN(lockDuration), BN(0));
        computedAML.averageMagnitude = aml_computeAverageMagnitude(
            computedAML.magnitude,
            BN(0),
            prevPoolState.totalParticipants.add(1),
        );
        computedAML.discount = aml_computeTarget(
            computedAML.magnitude,
            BN(0),
            BN(5e4),
            BN(50e4),
        );

        expect(participation.hasVotingPower).to.be.true;
        expect(participation.averageMagnitude).to.be.equal(
            computedAML.averageMagnitude,
        );

        // Check AML state
        const newPoolState = await adb.twAML(sglTokenMockAsset);

        expect(newPoolState.totalParticipants).to.be.equal(
            prevPoolState.totalParticipants.add(1),
        );
        expect(newPoolState.totalDeposited).to.be.equal(
            prevPoolState.totalDeposited.add(amount),
        );
        expect(newPoolState.cumulative).to.be.equal(computedAML.magnitude);
        expect(newPoolState.averageMagnitude).to.be.equal(
            computedAML.averageMagnitude,
        );

        // Check oTAP minting
        const oTAPTokenID = await oTAP.mintedOTAP();

        expect(oTAPTokenID).to.be.equal(1);
        expect(await oTAP.ownerOf(oTAPTokenID)).to.be.equal(signer.address);

        const [, oTAPToken] = await oTAP.attributes(oTAPTokenID);

        expect(oTAPToken.discount).to.be.equal(computedAML.discount);
        expect(oTAPToken.tOLP).to.be.equal(tokenID);
        expect(oTAPToken.expiry).to.be.equal(
            (await hre.ethers.provider.getBlock(lockTx.blockNumber!))
                .timestamp + lockDuration,
        );

        /// Check transfer of tOLP
        await expect(adb.participate(tokenID)).to.be.revertedWith(
            'adb: Not approved or owner',
        );
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(adb.address);

        // Check participation without enough voting power
        const user = users[0];
        const _amount = amount * 0.001 - 1; // < 0.1% of total weights
        await sglTokenMock.mintTo(user.address, _amount);
        await sglTokenMock.connect(user).approve(yieldBox.address, _amount);
        await yieldBox
            .connect(user)
            .depositAsset(
                sglTokenMockAsset,
                user.address,
                user.address,
                _amount,
                0,
            );
        const _ybAmount = await yieldBox
            .connect(user)
            .toAmount(
                sglTokenMockAsset,
                await yieldBox.balanceOf(user.address, sglTokenMockAsset),
                false,
            );
        await yieldBox.connect(user).setApprovalForAll(tOLP.address, true);
        await tOLP
            .connect(user)
            .lock(user.address, sglTokenMock.address, lockDuration, _ybAmount);
        const _tokenID = await tOLP.tokenCounter();
        await tOLP.connect(user).approve(adb.address, _tokenID);
        await adb.connect(user).participate(_tokenID);

        expect(await adb.twAML(sglTokenMockAsset)).to.be.deep.equal(
            newPoolState,
        ); // No change in AML state
    });

    it('should exit position', async () => {
        const {
            signer,
            users,
            tOLP,
            adb,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            yieldBox,
            oTAP,
        } = await loadFixture(setupFixture);

        // Setup adb
        await adb.oTAPBrokerClaim();
        await tapOFT.setMinter(adb.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 1e8;
        const lockDuration = 10;
        await tOLP.registerSingularity(
            sglTokenMock.address,
            sglTokenMockAsset,
            0,
        );

        await sglTokenMock.freeMint(amount);
        await sglTokenMock.approve(yieldBox.address, amount);
        await yieldBox.depositAsset(
            sglTokenMockAsset,
            signer.address,
            signer.address,
            amount,
            0,
        );

        const ybAmount = await yieldBox.toAmount(
            sglTokenMockAsset,
            await yieldBox.balanceOf(signer.address, sglTokenMockAsset),
            false,
        );
        await yieldBox.setApprovalForAll(tOLP.address, true);
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            ybAmount,
        );
        const tokenID = await tOLP.tokenCounter();

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(
            adb.exitPosition((await oTAP.mintedOTAP()).add(1)),
        ).to.be.revertedWith('adb: oTAP position does not exist');
        await snapshot.restore();

        // Participate
        await tOLP.approve(adb.address, tokenID);
        await adb.participate(tokenID);
        const oTAPTknID = await oTAP.mintedOTAP();
        const participation = await adb.participants(tokenID);
        const prevPoolState = await adb.twAML(sglTokenMockAsset);

        // Test exit
        await expect(adb.exitPosition(oTAPTknID)).to.be.revertedWith(
            'adb: Lock not expired',
        );
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(adb.address);

        await time.increase(lockDuration);
        await oTAP.approve(adb.address, oTAPTknID);
        await adb.exitPosition(oTAPTknID);

        // Check tokens transfer
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(signer.address);
        expect(await oTAP.exists(oTAPTknID)).to.be.false;

        // Check AML update
        const newPoolState = await adb.twAML(sglTokenMockAsset);

        expect(newPoolState.totalParticipants).to.be.equal(
            prevPoolState.totalParticipants.sub(1),
        );
        expect(newPoolState.totalDeposited).to.be.equal(
            prevPoolState.totalDeposited.sub(amount),
        );
        expect(newPoolState.cumulative).to.be.equal(
            prevPoolState.cumulative.sub(participation.averageMagnitude),
        );

        // Do not remove participation if not participating
        await snapshot.restore();

        const user = users[0];
        const _amount = amount * 0.001 - 1; // < 0.1% of total weights
        await sglTokenMock.mintTo(user.address, _amount);
        await sglTokenMock.connect(user).approve(yieldBox.address, _amount);
        await yieldBox
            .connect(user)
            .depositAsset(
                sglTokenMockAsset,
                user.address,
                user.address,
                _amount,
                0,
            );
        const _ybAmount = await yieldBox
            .connect(user)
            .toAmount(
                sglTokenMockAsset,
                await yieldBox.balanceOf(user.address, sglTokenMockAsset),
                false,
            );
        await yieldBox.connect(user).setApprovalForAll(tOLP.address, true);
        await tOLP
            .connect(user)
            .lock(user.address, sglTokenMock.address, lockDuration, _ybAmount);
        const _tokenID = await tOLP.tokenCounter();
        await tOLP.connect(user).approve(adb.address, _tokenID);
        await adb.connect(user).participate(_tokenID);

        await time.increase(lockDuration);

        const _oTAPTknID = await oTAP.mintedOTAP();
        await oTAP.connect(user).approve(adb.address, _oTAPTknID);
        await adb.connect(user).exitPosition(_oTAPTknID);

        expect(await adb.twAML(sglTokenMockAsset)).to.be.deep.equal(
            newPoolState,
        ); // No change in AML state
        expect((await adb.twAML(sglTokenMockAsset)).cumulative).to.be.equal(0);
    });

    it('should enter and exit multiple positions', async () => {
        const {
            signer,
            tOLP,
            adb,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            yieldBox,
            oTAP,
        } = await loadFixture(setupFixture);

        // Setup adb
        await adb.oTAPBrokerClaim();
        await tapOFT.setMinter(adb.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 3e8;
        const lockDuration = 10;
        await tOLP.registerSingularity(
            sglTokenMock.address,
            sglTokenMockAsset,
            0,
        );

        await sglTokenMock.freeMint(amount);
        await sglTokenMock.approve(yieldBox.address, amount);
        await yieldBox.depositAsset(
            sglTokenMockAsset,
            signer.address,
            signer.address,
            amount,
            0,
        );

        const ybAmount = await yieldBox.toAmount(
            sglTokenMockAsset,
            await yieldBox.balanceOf(signer.address, sglTokenMockAsset),
            false,
        );
        await yieldBox.setApprovalForAll(tOLP.address, true);
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            ybAmount.div(3),
        );
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            ybAmount.div(3),
        );
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            ybAmount.div(3),
        );
        const tokenID = await tOLP.tokenCounter();

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(
            adb.exitPosition((await oTAP.mintedOTAP()).add(1)),
        ).to.be.revertedWith('adb: oTAP position does not exist');
        await snapshot.restore();

        // Participate
        await tOLP.approve(adb.address, tokenID);
        await tOLP.approve(adb.address, tokenID.sub(1));
        await tOLP.approve(adb.address, tokenID.sub(2));
        await adb.participate(tokenID);
        await adb.participate(tokenID.sub(1));
        await adb.participate(tokenID.sub(2));

        const oTAPTknID = await oTAP.mintedOTAP();

        await time.increase(lockDuration);

        {
            // Exit 1
            await oTAP.approve(adb.address, oTAPTknID);
            await adb.exitPosition(oTAPTknID);
        }

        {
            // Exit 2
            await oTAP.approve(adb.address, oTAPTknID.sub(1));
            await adb.exitPosition(oTAPTknID.sub(1));
        }

        {
            // Exit 3
            await oTAP.approve(adb.address, oTAPTknID.sub(2));
            await adb.exitPosition(oTAPTknID.sub(2));
        }
    });

    it('should set a payment token', async () => {
        const { adb, users, stableMock, stableMockOracle } = await loadFixture(
            setupFixture,
        );

        await expect(
            adb
                .connect(users[0])
                .setPaymentToken(
                    stableMock.address,
                    stableMockOracle.address,
                    '0x00',
                ),
        ).to.be.revertedWith('Ownable: caller is not the owner');

        await expect(
            adb.setPaymentToken(
                stableMock.address,
                stableMockOracle.address,
                '0x00',
            ),
        )
            .to.emit(adb, 'SetPaymentToken')
            .withArgs(stableMock.address, stableMockOracle.address, '0x00');

        const paymentToken = await adb.paymentTokens(stableMock.address);
        expect(paymentToken.oracle).to.be.equal(stableMockOracle.address);
        expect(paymentToken.oracleData).to.be.equal('0x00');

        await expect(
            adb.setPaymentToken(
                stableMock.address,
                hre.ethers.constants.AddressZero,
                '0x00',
            ),
        )
            .to.emit(adb, 'SetPaymentToken')
            .withArgs(
                stableMock.address,
                hre.ethers.constants.AddressZero,
                '0x00',
            );

        expect(
            (await adb.paymentTokens(stableMock.address)).oracle,
        ).to.be.equal(hre.ethers.constants.AddressZero);
    });

    it('should increment the epoch', async () => {
        const {
            adb,
            tapOFT,
            tOLP,
            sglTokenMock,
            sglTokenMockAsset,
            tapOracleMock,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);

        // Setup adb
        await adb.oTAPBrokerClaim();
        await tapOFT.setMinter(adb.address);

        // No singularities
        await expect(adb.newEpoch()).to.be.revertedWith(
            'adb: No active singularities',
        );

        // Register sgl
        const tapPrice = BN(1e18).mul(2);
        await tapOracleMock.set(tapPrice);
        await tOLP.registerSingularity(
            sglTokenMock.address,
            sglTokenMockAsset,
            0,
        );

        const snapshot = await takeSnapshot();
        // Check epoch update
        const txNewEpoch = await adb.newEpoch();
        expect(await adb.epoch()).to.be.equal(1);
        expect(await adb.lastEpochUpdate()).to.be.equal(
            (await hre.ethers.provider.getBlock(txNewEpoch.blockNumber!))
                .timestamp,
        );
        expect(await adb.epochTAPValuation()).to.be.equal(tapPrice);

        const emittedTAP = await tapOFT.getCurrentWeekEmission();

        // Check TAP minting for 1 SGL asset
        expect(emittedTAP.gt(0)).to.be.true;
        expect(await adb.singularityGauges(1, sglTokenMockAsset)).to.be.equal(
            emittedTAP,
        );

        // Check TAP minting for 2 SGL assets with equal weights
        await snapshot.restore();
        await tOLP.registerSingularity(
            sglTokenMock2.address,
            sglTokenMock2Asset,
            0,
        );
        await adb.newEpoch();
        expect(await adb.singularityGauges(1, sglTokenMockAsset)).to.be.equal(
            emittedTAP.div(2),
        );
        expect(await adb.singularityGauges(1, sglTokenMock2Asset)).to.be.equal(
            emittedTAP.div(2),
        );

        // Check TAP minting for 2 SGL assets with different weights
        await snapshot.restore();
        await tOLP.registerSingularity(
            sglTokenMock2.address,
            sglTokenMock2Asset,
            2,
        );
        await adb.newEpoch();
        expect(await adb.singularityGauges(1, sglTokenMockAsset)).to.be.equal(
            emittedTAP.div(3),
        );
        expect(await adb.singularityGauges(1, sglTokenMock2Asset)).to.be.equal(
            emittedTAP.mul(2).div(3),
        );
    });

    it('should return correct OTC details', async () => {
        const {
            users,
            yieldBox,
            adb,
            tapOFT,
            tOLP,
            oTAP,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
            stableMock,
            stableMockOracle,
            ethMock,
            ethMockOracle,
        } = await loadFixture(setupFixture);

        await setupEnv(
            adb,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await adb.newEpoch();

        await adb.setPaymentToken(
            stableMock.address,
            stableMockOracle.address,
            '0x00',
        );
        await adb.setPaymentToken(
            ethMock.address,
            ethMockOracle.address,
            '0x00',
        );
        const userLock1 = await lockAndParticipate(
            users[0],
            3e8,
            3600,
            tOLP,
            adb,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );
        const userLock2 = await lockAndParticipate(
            users[1],
            1e8,
            3600,
            tOLP,
            adb,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );

        const epoch = await adb.epoch();

        const snapshot = await takeSnapshot();

        /// FULL ELIGIBLE STABLE

        // Exercise for full eligible TAP with 1e6 decimals stable, 50% discount
        {
            const eligibleTapAmount = userLock1.ybAmount
                .mul(await adb.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await stableMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment
                .sub(discount)
                .div((1e12).toString());

            const otcDetails = await adb
                .connect(users[0])
                .getOTCDealDetails(
                    userLock1.oTAPTokenID,
                    stableMock.address,
                    0,
                );
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }

        // Exercise for full eligible TAP with 1e6 decimals stable, 20.7083% discount
        {
            const eligibleTapAmount = userLock2.ybAmount
                .mul(await adb.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await stableMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment
                .mul(userLock2.oTAPOption.discount)
                .div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await adb
                .connect(users[1])
                .getOTCDealDetails(
                    userLock2.oTAPTokenID,
                    stableMock.address,
                    0,
                );
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }

        await snapshot.restore();

        /// FULL ELIGIBLE WETH

        // Exercise for full eligible TAP with 1e18 decimals ETH, 50% discount
        {
            const eligibleTapAmount = userLock1.ybAmount
                .mul(await adb.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await ethMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await adb
                .connect(users[0])
                .getOTCDealDetails(userLock1.oTAPTokenID, ethMock.address, 0);
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }

        // Exercise for full eligible TAP with 1e18 decimals token, 20.7083% discount
        {
            const eligibleTapAmount = userLock2.ybAmount
                .mul(await adb.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await ethMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment
                .mul(userLock2.oTAPOption.discount)
                .div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await adb
                .connect(users[1])
                .getOTCDealDetails(userLock2.oTAPTokenID, ethMock.address, 0);
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }

        await snapshot.restore();

        /// 1 TAP STABLE

        // Exercise for 1 TAP with 1e6 decimals stable, 50% discount
        {
            const otcDealAmountInUSD = BN(33e17).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div(
                (await stableMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await adb
                .connect(users[0])
                .getOTCDealDetails(
                    userLock1.oTAPTokenID,
                    stableMock.address,
                    (1e18).toString(),
                );
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }

        // Exercise for 1 TAP with 1e6 decimals stable, 20.7083% discount
        {
            const otcDealAmountInUSD = BN(33e17).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div(
                (await stableMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment
                .mul(userLock2.oTAPOption.discount)
                .div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await adb
                .connect(users[1])
                .getOTCDealDetails(
                    userLock2.oTAPTokenID,
                    stableMock.address,
                    (1e18).toString(),
                );
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }

        await snapshot.restore();

        /// 1 TAP ETH

        // Exercise for 1 TAP with 1e18 decimals token, 50% discount
        {
            const otcDealAmountInUSD = BN(33e17).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div(
                (await ethMockOracle.get('0x00'))[1],
            ); // ETH price at 1200
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await adb
                .connect(users[0])
                .getOTCDealDetails(
                    userLock1.oTAPTokenID,
                    ethMock.address,
                    (1e18).toString(),
                );
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }
        // Exercise for 1 TAP with 1e18 decimals token, 20.7083% discount
        {
            const otcDealAmountInUSD = BN(33e17).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div(
                (await ethMockOracle.get('0x00'))[1],
            ); // ETH price at 1200
            const discount = rawPayment
                .mul(userLock2.oTAPOption.discount)
                .div(1e4 * 100);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await adb
                .connect(users[1])
                .getOTCDealDetails(
                    userLock2.oTAPTokenID,
                    ethMock.address,
                    (1e18).toString(),
                );
            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }
    });

    it('should exercise an option fully or partially per allowed epoch amount', async () => {
        const {
            users,
            yieldBox,
            adb,
            tapOFT,
            tOLP,
            oTAP,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
            stableMock,
            stableMockOracle,
            ethMock,
            ethMockOracle,
        } = await loadFixture(setupFixture);

        await setupEnv(
            adb,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await adb.newEpoch();

        await adb.setPaymentToken(
            stableMock.address,
            stableMockOracle.address,
            '0x00',
        );
        await adb.setPaymentToken(
            ethMock.address,
            ethMockOracle.address,
            '0x00',
        );
        const userLock1 = await lockAndParticipate(
            users[0],
            3e8,
            1_209_600, // 2 week
            tOLP,
            adb,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );
        const userLock2 = await lockAndParticipate(
            users[1],
            1e8,
            1_209_600, // 2 week
            tOLP,
            adb,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );

        // Check requirements
        await expect(
            adb
                .connect(users[1])
                .exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0),
        ).to.be.rejectedWith('adb: Not approved or owner');
        const snapshot = await takeSnapshot();
        await adb.setPaymentToken(
            stableMock.address,
            hre.ethers.constants.AddressZero,
            '0x00',
        );
        await expect(
            adb
                .connect(users[0])
                .exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0),
        ).to.be.rejectedWith('adb: Payment token not supported');
        await snapshot.restore();
        await time.increase(userLock1.lockDuration);
        await expect(
            adb
                .connect(users[0])
                .exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0),
        ).to.be.rejectedWith('adb: Option expired');
        await snapshot.restore();

        // Gauge emission check
        const epoch = await adb.epoch();
        const sglGaugeTokenMock1 = (await tapOFT.getCurrentWeekEmission())
            .mul(2)
            .div(3);
        const sglGaugeTokenMock2 = (await tapOFT.getCurrentWeekEmission())
            .mul(1)
            .div(3);
        expect(await adb.singularityGauges(epoch, sglTokenMockAsset)).to.equal(
            sglGaugeTokenMock1,
        );
        expect(await adb.singularityGauges(epoch, sglTokenMock2Asset)).to.equal(
            sglGaugeTokenMock2,
        );

        // Exercise option for user 1 for full eligible TAP amount
        let user1EligibleTapAmount;
        let user1PaymentAmount;
        {
            const otcDetails = await adb
                .connect(users[0])
                .getOTCDealDetails(
                    userLock1.oTAPTokenID,
                    stableMock.address,
                    0,
                );
            const eligibleTapAmount = otcDetails.eligibleTapAmount;
            user1EligibleTapAmount = eligibleTapAmount;
            const paymentTokenToSend = otcDetails.paymentTokenAmount;
            user1PaymentAmount = paymentTokenToSend;

            // ERC20 checks
            await expect(
                adb
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await stableMock.mintTo(users[0].address, paymentTokenToSend);
            await expect(
                adb
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await stableMock
                .connect(users[0])
                .approve(adb.address, paymentTokenToSend);

            // Exercise option checks
            await expect(
                adb
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        eligibleTapAmount,
                    ),
            )
                .to.emit(adb, 'ExerciseOption')
                .withArgs(
                    epoch,
                    users[0].address,
                    stableMock.address,
                    userLock1.oTAPTokenID,
                    eligibleTapAmount,
                ); // Successful exercise

            expect(await tapOFT.balanceOf(users[0].address)).to.be.equal(
                eligibleTapAmount,
            ); // Check TAP transfer to user
            expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal(
                (await tapOFT.mintedInWeek(epoch)).sub(eligibleTapAmount),
            ); // Check TAP subtraction from TAP contract
            expect(await stableMock.balanceOf(adb.address)).to.be.equal(
                paymentTokenToSend,
            ); // Check payment token transfer to adb contract

            expect(
                await adb.oTAPCalls(userLock1.oTAPTokenID, epoch),
            ).to.be.equal(eligibleTapAmount);

            // end
            await expect(
                adb
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        eligibleTapAmount,
                    ),
            ).to.be.rejectedWith('adb: Too high');
        }

        let user2EligibleTapAmount;
        let user2PaymentAmount;
        // Exercise option for user 2 for half eligible TAP amount
        {
            const { eligibleTapAmount: __fullEligibleTapAMount } = await adb
                .connect(users[1])
                .getOTCDealDetails(userLock2.oTAPTokenID, ethMock.address, 0);
            const tapAmountWanted = __fullEligibleTapAMount.div(2);
            const { paymentTokenAmount: fullPaymentTokenToSend } = await adb
                .connect(users[1])
                .getOTCDealDetails(
                    userLock2.oTAPTokenID,
                    ethMock.address,
                    __fullEligibleTapAMount,
                );
            const halfPaymentTokenToSend = fullPaymentTokenToSend.div(2);
            user2EligibleTapAmount = tapAmountWanted;
            user2PaymentAmount = halfPaymentTokenToSend;

            await expect(
                adb
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await ethMock.mintTo(users[1].address, fullPaymentTokenToSend);

            await expect(
                adb
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await ethMock
                .connect(users[1])
                .approve(adb.address, fullPaymentTokenToSend);

            // Exercise option checks
            await expect(
                adb
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            )
                .to.emit(adb, 'ExerciseOption')
                .withArgs(
                    epoch,
                    users[1].address,
                    ethMock.address,
                    userLock2.oTAPTokenID,
                    tapAmountWanted,
                ); // Successful exercise

            expect(
                await adb.oTAPCalls(userLock2.oTAPTokenID, epoch),
            ).to.be.equal(tapAmountWanted); // Check exercised amount has been updated

            expect(await tapOFT.balanceOf(users[1].address)).to.be.equal(
                tapAmountWanted,
            ); // Check TAP transfer to user

            expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal(
                (await tapOFT.mintedInWeek(epoch))
                    .sub(tapAmountWanted)
                    .sub(user1EligibleTapAmount),
            ); // Check TAP subtraction from TAP contract

            expect(await ethMock.balanceOf(adb.address)).to.be.equal(
                halfPaymentTokenToSend,
            ); // Check payment token transfer to adb contract

            // Exercise option for user 2 for remaining eligible TAP amount
            await expect(
                adb
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            )
                .to.emit(adb, 'ExerciseOption')
                .withArgs(
                    epoch,
                    users[1].address,
                    ethMock.address,
                    userLock2.oTAPTokenID,
                    tapAmountWanted,
                ); // Successful exercise

            expect(
                await adb.oTAPCalls(userLock2.oTAPTokenID, epoch),
            ).to.be.equal(__fullEligibleTapAMount); // Check exercised amount has been updated

            expect(await tapOFT.balanceOf(users[1].address)).to.be.equal(
                __fullEligibleTapAMount,
            ); // Check TAP transfer to user

            expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal(
                (await tapOFT.mintedInWeek(epoch))
                    .sub(__fullEligibleTapAMount)
                    .sub(user1EligibleTapAmount),
            ); // Check TAP subtraction from TAP contract

            expect(await ethMock.balanceOf(adb.address)).to.be.closeTo(
                fullPaymentTokenToSend,
                1,
            ); // Check payment token transfer to adb contract

            // Can't exercise option again for this epoch
            await expect(
                adb
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            ).to.be.rejectedWith('adb: Too high');
        }

        // Jump to next epoch
        await time_travel(604800); // 1 week
        await adb.newEpoch();

        // Exercise option for user 1 for remaining eligible TAP amount
        await stableMock.mintTo(users[0].address, user1PaymentAmount);
        await stableMock
            .connect(users[0])
            .approve(adb.address, user1PaymentAmount);
        await expect(
            adb
                .connect(users[0])
                .exerciseOption(
                    userLock1.oTAPTokenID,
                    stableMock.address,
                    user1EligibleTapAmount,
                ),
        )
            .to.emit(adb, 'ExerciseOption')
            .withArgs(
                epoch.add(1),
                users[0].address,
                stableMock.address,
                userLock1.oTAPTokenID,
                user1EligibleTapAmount,
            ); // Successful exercise

        // Exercise option for user 2 for remaining eligible TAP amount
        await ethMock.mintTo(users[1].address, user2PaymentAmount);
        await ethMock
            .connect(users[1])
            .approve(adb.address, user2PaymentAmount);
        await expect(
            adb
                .connect(users[1])
                .exerciseOption(
                    userLock2.oTAPTokenID,
                    ethMock.address,
                    user2EligibleTapAmount,
                ),
        )
            .to.emit(adb, 'ExerciseOption')
            .withArgs(
                epoch.add(1),
                users[1].address,
                ethMock.address,
                userLock2.oTAPTokenID,
                user2EligibleTapAmount,
            ); // Successful exercise
    });

    it('should set payment beneficiary', async () => {
        const { users, adb } = await loadFixture(setupFixture);

        await expect(
            adb.connect(users[0]).setPaymentTokenBeneficiary(users[0].address),
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await adb.setPaymentTokenBeneficiary(users[0].address);
        expect(await adb.paymentTokenBeneficiary()).to.be.equal(
            users[0].address,
        );
    });

    it('should collect payment token', async () => {
        const {
            signer,
            users,
            paymentTokenBeneficiary,
            yieldBox,
            adb,
            tapOFT,
            tOLP,
            oTAP,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
            stableMock,
            stableMockOracle,
        } = await loadFixture(setupFixture);

        await setupEnv(
            adb,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await adb.newEpoch();

        await adb.setPaymentToken(
            stableMock.address,
            stableMockOracle.address,
            '0x00',
        );
        const userLock1 = await lockAndParticipate(
            users[0],
            3e8,
            3600,
            tOLP,
            adb,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );
        const otcDetails = await adb.getOTCDealDetails(
            userLock1.oTAPTokenID,
            stableMock.address,
            0,
        );

        // Exercise
        await stableMock.mintTo(
            users[0].address,
            otcDetails.paymentTokenAmount,
        );

        await stableMock
            .connect(users[0])
            .approve(adb.address, otcDetails.paymentTokenAmount);
        await adb
            .connect(users[0])
            .exerciseOption(
                userLock1.oTAPTokenID,
                stableMock.address,
                otcDetails.eligibleTapAmount,
            );

        // Collect
        await expect(
            adb.connect(users[0]).collectPaymentTokens([stableMock.address]),
        ).to.be.rejectedWith('Ownable: caller is not the owner');
        await adb.collectPaymentTokens([stableMock.address]);
        expect(await stableMock.balanceOf(adb.address)).to.be.equal(0);
        expect(
            await stableMock.balanceOf(paymentTokenBeneficiary.address),
        ).to.be.equal(otcDetails.paymentTokenAmount);
    });

    it('Should be able to use permit on TapOFT', async () => {
        const {
            signer,
            users,
            oTAP,
            tOLP,
            adb,
            tapOFT,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);
        await setupEnv(
            adb,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );

        // Setup
        const userLock1 = await lockAndParticipate(
            signer,
            3e8,
            3600,
            tOLP,
            adb,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );
        const tokenID = userLock1.oTAPTokenID;

        const [normalUser, otherAddress] = users;

        const deadline =
            (await hre.ethers.provider.getBlock('latest')).timestamp + 10_000;
        const { v, r, s } = await getERC721PermitSignature(
            signer,
            oTAP,
            normalUser.address,
            tokenID,
            BN(deadline),
        );

        // Check if it works
        const snapshot = await takeSnapshot();
        await expect(
            oTAP.permit(normalUser.address, tokenID, deadline, v, r, s),
        )
            .to.emit(oTAP, 'Approval')
            .withArgs(signer.address, normalUser.address, tokenID);

        // Check that it can't be used twice
        await expect(
            oTAP.permit(normalUser.address, tokenID, deadline, v, r, s),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used after deadline
        await time_travel(10_001);
        await expect(
            oTAP.permit(normalUser.address, tokenID, deadline, v, r, s),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used with wrong signature
        const {
            v: v2,
            r: r2,
            s: s2,
        } = await getERC721PermitSignature(
            signer,
            oTAP,
            otherAddress.address,
            tokenID,
            BN(deadline),
        );
        await expect(
            oTAP.permit(normalUser.address, tokenID, deadline, v2, r2, s2),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can be batch called
        const permit = oTAP.interface.encodeFunctionData('permit', [
            normalUser.address,
            tokenID,
            deadline,
            v,
            r,
            s,
        ]);
        const transfer = oTAP.interface.encodeFunctionData('transferFrom', [
            signer.address,
            normalUser.address,
            tokenID,
        ]);

        await expect(oTAP.connect(normalUser).batch([permit, transfer], true))
            .to.emit(oTAP, 'Transfer')
            .withArgs(signer.address, normalUser.address, tokenID);
    });
});
