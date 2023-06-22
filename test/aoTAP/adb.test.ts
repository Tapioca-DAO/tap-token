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
import { BigNumber, BigNumberish, BytesLike, Wallet } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { setupFixture } from './fixture.aoTAP';

describe.only('AirdropBroker', () => {
    const setupEnv = async (adb: AirdropBroker, tapOFT: TapOFT) => {
        await adb.aoTAPBrokerClaim();
        await tapOFT.transfer(
            adb.address,
            BN((1e18).toString()).mul(2_5000_000),
        );
    };
    const newEpoch = async (adb: AirdropBroker) => {
        await time_travel((await adb.EPOCH_DURATION()).toNumber());
        await adb.newEpoch();
    };
    const adbRegisterAndParticipatePhase1 = async (
        users: Wallet[],
        amounts: BigNumberish[],
        adb: AirdropBroker,
        aoTAP: AOTAP,
    ) => {
        await adb.registerUserForPhase(
            1,
            users.map((e) => e.address),
            amounts,
        );

        await newEpoch(adb);
        expect(await adb.epoch()).to.be.eq(BN(1));

        const registrations = [];
        for (const user of users) {
            await adb.connect(user).participate(user.address);
            // Get aoTAP tokenID and check aoTAP option
            const aoTAPTokenID = await aoTAP.mintedAOTAP();
            const aoTAPOption = await aoTAP.options(aoTAPTokenID);
            registrations.push({
                user,
                aoTAPTokenID,
                aoTAPOption,
            });
        }

        return registrations;
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
            const users = await generatePhase1_4Signers({
                initialAmount: 1_500_000,
            });
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
            const users = await generatePhase1_4Signers({
                initialAmount: 1_500_000,
            });
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
                const mintedAOTAP = await aoTAP.mintedAOTAP();
                // Participate
                await expect(
                    adb.connect(user.wallet).participate(user.wallet.address),
                )
                    .to.emit(adb, 'Participate')
                    .withArgs(1, mintedAOTAP.add(1));

                // Get aoTAP tokenID and check aoTAP option
                const aoTAPTokenID = mintedAOTAP.add(1);
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

        it.only('Should get correct OTC details', async () => {
            const {
                signer,
                users: [rndSigner],
                adb,
                tapOFT,
                aoTAP,
                generatePhase1_4Signers,
                stableMock,
                stableMockOracle,
                ethMock,
                ethMockOracle,
            } = await loadFixture(setupFixture);
            setupEnv(adb, tapOFT);

            //---- User registration and participation
            const users = await generatePhase1_4Signers({
                initialAmount: 1_500_000,
            });
            const registrations = await adbRegisterAndParticipatePhase1(
                users.map((e) => e.wallet),
                users.map((e) => e.amount),
                adb,
                aoTAP,
            );

            //---- Test With USDC as payment
            await adb.setPaymentToken(
                stableMock.address,
                stableMockOracle.address,
                '0x00',
            );

            // Verify requirements
            const snapshot = await takeSnapshot();
            await expect(
                adb
                    .connect(registrations[0].user)
                    .getOTCDealDetails(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.not.be.reverted;

            await expect(
                adb
                    .connect(registrations[0].user)
                    .getOTCDealDetails(
                        registrations[0].aoTAPTokenID,
                        ethMock.address,
                        0,
                    ),
            ).to.be.revertedWith('adb: Payment token not supported');

            await expect(
                adb
                    .connect(registrations[0].user)
                    .getOTCDealDetails(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        registrations[0].aoTAPOption.amount.add(1),
                    ),
            ).to.be.revertedWith('adb: Too high');

            await time_travel((await adb.EPOCH_DURATION()).toNumber());
            await expect(
                adb
                    .connect(registrations[0].user)
                    .getOTCDealDetails(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.revertedWith('adb: Option expired');

            await snapshot.restore();

            //---- Test With USDC as payment
            {
                await adb.setPaymentToken(
                    stableMock.address,
                    stableMockOracle.address,
                    '0x00',
                );
                // Check OTC details
                const registration = registrations[0];
                const otcDealAmountInUSD = BN(33e17).mul((1e18).toString());
                const rawPayment = otcDealAmountInUSD.div(
                    (await stableMockOracle.get('0x00'))[1],
                ); // USDC price at 1
                const discount = rawPayment.mul(50).div(100);
                const paymentTokenToSend = rawPayment
                    .sub(discount)
                    .div((1e12).toString());

                const otcDetails = await adb
                    .connect(registration.user)
                    .getOTCDealDetails(
                        registration.aoTAPTokenID,
                        stableMock.address,
                        (1e18).toString(),
                    );

                expect(otcDetails.eligibleTapAmount).to.be.equal(
                    registration.aoTAPOption.amount,
                );
                expect(otcDetails.paymentTokenAmount).to.be.equal(
                    paymentTokenToSend,
                );
            }
            // Check OTC details
            //---- Test With USDC as payment
            await adb.setPaymentToken(
                ethMock.address,
                ethMockOracle.address,
                '0x00',
            );

            // Check OTC details
            {
                const registration = registrations[0];
                const otcDealAmountInUSD = BN(33e17).mul(
                    registration.aoTAPOption.amount,
                );
                const rawPayment = otcDealAmountInUSD.div(
                    (await ethMockOracle.get('0x00'))[1],
                ); // USDC price at 1
                const discount = rawPayment.mul(50).div(100);
                const paymentTokenToSend = rawPayment.sub(discount);

                const otcDetails = await adb
                    .connect(registration.user)
                    .getOTCDealDetails(
                        registration.aoTAPTokenID,
                        ethMock.address,
                        0,
                    );
                expect(otcDetails.eligibleTapAmount).to.be.equal(
                    registration.aoTAPOption.amount,
                );
                expect(otcDetails.paymentTokenAmount).to.be.equal(
                    paymentTokenToSend,
                );
            }
        });

        it('should exercise an option fully or partially per allowed amount', async () => {
            const {
                adb,
                tapOFT,
                aoTAP,
                generatePhase1_4Signers,
                stableMock,
                stableMockOracle,
                ethMock,
                ethMockOracle,
            } = await loadFixture(setupFixture);
            setupEnv(adb, tapOFT);

            // Gen users and register them
            const users = await generatePhase1_4Signers({
                initialAmount: 1_500_000,
            });
            const registrations = await adbRegisterAndParticipatePhase1(
                users.map((e) => e.wallet),
                users.map((e) => e.amount),
                adb,
                aoTAP,
            );

            const epoch = await adb.epoch();

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
            // Check requirements
            await expect(
                adb
                    .connect(users[1].wallet)
                    .exerciseOption(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejectedWith('adb: Not approved or owner');
            const snapshot = await takeSnapshot();
            await adb.setPaymentToken(
                stableMock.address,
                hre.ethers.constants.AddressZero,
                '0x00',
            );
            await expect(
                adb
                    .connect(users[0].wallet)
                    .exerciseOption(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejectedWith('adb: Payment token not supported');
            await snapshot.restore();
            await time.increase(await adb.EPOCH_DURATION());
            await expect(
                adb
                    .connect(users[0].wallet)
                    .exerciseOption(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejectedWith('adb: Option expired');
            await snapshot.restore();

            // Exercise option for user 1 for full eligible TAP amount
            let user1EligibleTapAmount;
            let user1PaymentAmount;
            {
                const otcDetails = await adb
                    .connect(users[0].wallet)
                    .getOTCDealDetails(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        0,
                    );
                const eligibleTapAmount = otcDetails.eligibleTapAmount;
                user1EligibleTapAmount = eligibleTapAmount;
                const paymentTokenToSend = otcDetails.paymentTokenAmount;
                user1PaymentAmount = paymentTokenToSend;

                // ERC20 checks
                console.log(otcDetails);
                hre.tracer.enabled = true;
                await expect(
                    adb
                        .connect(users[0].wallet)
                        .exerciseOption(
                            registrations[0].aoTAPTokenID,
                            stableMock.address,
                            0,
                        ),
                ).to.be.rejectedWith('ERC20: insufficient allowance');
                await stableMock.mintTo(
                    users[0].wallet.address,
                    paymentTokenToSend,
                );
                await expect(
                    adb
                        .connect(users[0].wallet)
                        .exerciseOption(
                            registrations[0].aoTAPTokenID,
                            stableMock.address,
                            0,
                        ),
                ).to.be.rejectedWith('ERC20: insufficient allowance');
                await stableMock
                    .connect(users[0].wallet)
                    .approve(adb.address, paymentTokenToSend);

                // Exercise option checks
                await expect(
                    adb
                        .connect(users[0].wallet)
                        .exerciseOption(
                            registrations[0].aoTAPTokenID,
                            stableMock.address,
                            0,
                        ),
                )
                    .to.emit(adb, 'ExerciseOption')
                    .withArgs(
                        epoch,
                        users[0].wallet.address,
                        stableMock.address,
                        registrations[0].aoTAPTokenID,
                        eligibleTapAmount,
                    ); // Successful exercise

                expect(
                    await tapOFT.balanceOf(users[0].wallet.address),
                ).to.be.equal(eligibleTapAmount); // Check TAP transfer to user
                expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal(
                    (await tapOFT.mintedInWeek(epoch)).sub(eligibleTapAmount),
                ); // Check TAP subtraction from TAP contract
                expect(await stableMock.balanceOf(adb.address)).to.be.equal(
                    paymentTokenToSend,
                ); // Check payment token transfer to adb contract

                expect(
                    await adb.aoTAPCalls(registrations[0].aoTAPTokenID, epoch),
                ).to.be.equal(eligibleTapAmount);

                // end
                await expect(
                    adb
                        .connect(users[0].wallet)
                        .exerciseOption(
                            registrations[0].aoTAPTokenID,
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
                    .connect(users[1].wallet)
                    .getOTCDealDetails(
                        registrations[1].aoTAPTokenID,
                        ethMock.address,
                        0,
                    );
                const tapAmountWanted = __fullEligibleTapAMount.div(2);
                const { paymentTokenAmount: fullPaymentTokenToSend } = await adb
                    .connect(users[1].wallet)
                    .getOTCDealDetails(
                        registrations[1].aoTAPTokenID,
                        ethMock.address,
                        __fullEligibleTapAMount,
                    );
                const halfPaymentTokenToSend = fullPaymentTokenToSend.div(2);
                user2EligibleTapAmount = tapAmountWanted;
                user2PaymentAmount = halfPaymentTokenToSend;

                await expect(
                    adb
                        .connect(users[1].wallet)
                        .exerciseOption(
                            registrations[1].aoTAPTokenID,
                            ethMock.address,
                            tapAmountWanted,
                        ),
                ).to.be.rejectedWith('ERC20: insufficient allowance');
                await ethMock.mintTo(
                    users[1].wallet.address,
                    fullPaymentTokenToSend,
                );

                await expect(
                    adb
                        .connect(users[1].wallet)
                        .exerciseOption(
                            registrations[1].aoTAPTokenID,
                            ethMock.address,
                            tapAmountWanted,
                        ),
                ).to.be.rejectedWith('ERC20: insufficient allowance');
                await ethMock
                    .connect(users[1].wallet)
                    .approve(adb.address, fullPaymentTokenToSend);

                // Exercise option checks
                await expect(
                    adb
                        .connect(users[1].wallet)
                        .exerciseOption(
                            registrations[1].aoTAPTokenID,
                            ethMock.address,
                            tapAmountWanted,
                        ),
                )
                    .to.emit(adb, 'ExerciseOption')
                    .withArgs(
                        epoch,
                        users[1].wallet.address,
                        ethMock.address,
                        registrations[1].aoTAPTokenID,
                        tapAmountWanted,
                    ); // Successful exercise

                expect(
                    await adb.aoTAPCalls(registrations[1].aoTAPTokenID, epoch),
                ).to.be.equal(tapAmountWanted); // Check exercised amount has been updated

                expect(
                    await tapOFT.balanceOf(users[1].wallet.address),
                ).to.be.equal(tapAmountWanted); // Check TAP transfer to user

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
                        .connect(users[1].wallet)
                        .exerciseOption(
                            registrations[1].aoTAPTokenID,
                            ethMock.address,
                            tapAmountWanted,
                        ),
                )
                    .to.emit(adb, 'ExerciseOption')
                    .withArgs(
                        epoch,
                        users[1].wallet.address,
                        ethMock.address,
                        registrations[1].aoTAPTokenID,
                        tapAmountWanted,
                    ); // Successful exercise

                expect(
                    await adb.aoTAPCalls(registrations[1].aoTAPTokenID, epoch),
                ).to.be.equal(__fullEligibleTapAMount); // Check exercised amount has been updated

                expect(
                    await tapOFT.balanceOf(users[1].wallet.address),
                ).to.be.equal(__fullEligibleTapAMount); // Check TAP transfer to user

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
                        .connect(users[1].wallet)
                        .exerciseOption(
                            registrations[1].aoTAPTokenID,
                            ethMock.address,
                            tapAmountWanted,
                        ),
                ).to.be.rejectedWith('adb: Too high');
            }
        });
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
        const { adb, tapOFT, tapOracleMock } = await loadFixture(setupFixture);

        // Setup adb
        await setupEnv(adb, tapOFT);

        // Check epoch update
        const txNewEpoch = await adb.newEpoch();
        expect(await adb.epoch()).to.be.equal(1);
        expect(await adb.lastEpochUpdate()).to.be.equal(
            (await hre.ethers.provider.getBlock(txNewEpoch.blockNumber!))
                .timestamp,
        );

        const tapPrice = BN(1e18).mul(2);
        await tapOracleMock.set(tapPrice);
        expect(await adb.epochTAPValuation()).to.be.equal(tapPrice);

        await adb.newEpoch();
        expect(await adb.epoch()).to.be.equal(2);
    });

    it('should exercise an option fully or partially per allowed epoch amount', async () => {
        const {
            users,
            adb,
            tapOFT,
            stableMock,
            stableMockOracle,
            ethMock,
            ethMockOracle,
        } = await loadFixture(setupFixture);

        await setupEnv(adb, tapOFT);
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
            adb,
            tapOFT,
            stableMock,
            stableMockOracle,
        } = await loadFixture(setupFixture);

        await setupEnv(adb, tapOFT);
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
