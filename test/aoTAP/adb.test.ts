import {
    loadFixture,
    takeSnapshot,
    time,
} from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { BigNumberish, BytesLike, Wallet } from 'ethers';
import hre from 'hardhat';
import { AOTAP, AirdropBroker, TapOFT } from '../../typechain';
import { BN, time_travel } from '../test.utils';
import { setupADBPhase2Fixtures, setupFixture } from './fixture.aoTAP';
import MerkleTree from 'merkletreejs';

describe('AirdropBroker', () => {
    const setupEnv = async (adb: AirdropBroker, tapOFT: TapOFT) => {
        await adb.aoTAPBrokerClaim();
        await tapOFT.transfer(
            adb.address,
            BN((1e18).toString()).mul(2_500_000),
        );
    };
    const newEpoch = async (adb: AirdropBroker) => {
        await time_travel((await adb.EPOCH_DURATION()).toNumber());
        await adb.newEpoch();
    };

    const loadPhase2UserWallet = async (adb: AirdropBroker, pk: string) => {
        const wallet = new hre.ethers.Wallet(pk, hre.ethers.provider);
        await hre.ethers.provider.send('hardhat_setBalance', [
            wallet.address,
            hre.ethers.utils.hexStripZeros(
                hre.ethers.utils.parseEther(String(100000))._hex,
            ),
        ]);

        return wallet;
    };
    const encodePhase2Data = (role: BigNumberish, merkleProof: BytesLike[]) => {
        return hre.ethers.utils.defaultAbiCoder.encode(
            ['uint256', 'bytes32[]'],
            [role, merkleProof],
        );
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
        expect(await adb.epochTAPValuation()).to.be.eq(0);
        expect(await adb.lastEpochUpdate()).to.be.eq(0);
        expect(await adb.epoch()).to.be.eq(0);

        // Phase 1
        expect(await adb.PHASE_1_DISCOUNT()).to.be.eq(BN(50 * 1e4));

        // Phase2
        expect(await adb.phase2MerkleRoots(0)).to.be.eq(
            hre.ethers.utils.hexZeroPad(hre.ethers.utils.hexlify(0), 32),
        );
        expect(await adb.PHASE_2_AMOUNT_PER_USER(0)).to.be.eq(BN(200));
        expect(await adb.PHASE_2_AMOUNT_PER_USER(1)).to.be.eq(BN(190));
        expect(await adb.PHASE_2_AMOUNT_PER_USER(2)).to.be.eq(BN(200));
        expect(await adb.PHASE_2_AMOUNT_PER_USER(3)).to.be.eq(BN(190));

        // Phase3
        expect(await adb.PHASE_3_AMOUNT_PER_USER()).to.be.eq(BN(714));
        expect(await adb.PHASE_3_DISCOUNT()).to.be.eq(BN(50 * 1e4));

        // Phase4
        expect(await adb.PHASE_4_DISCOUNT()).to.be.eq(BN(33 * 1e4));

        expect(await adb.EPOCH_DURATION()).to.be.eq(BN(2 * 24 * 60 * 60)); // 2 days
    });

    describe('Phase 1', () => {
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
            ).to.be.reverted;

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
            await expect(adb.connect(users[0].wallet).participate('0x00')).to.be
                .reverted;

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
                ).to.reverted;
            }
        });
    });

    describe('Phase 2', () => {
        it('Should merkle roots for phase 2 on each role', async () => {
            const {
                users: [rndSigner],
                adb,
            } = await loadFixture(setupFixture);
            const { phase2MerkleTree } = await loadFixture(
                setupADBPhase2Fixtures,
            );

            await expect(
                adb
                    .connect(rndSigner)
                    .setPhase2MerkleRoots(
                        phase2MerkleTree.map((e) => `0x${e.root}`) as [
                            string,
                            string,
                            string,
                            string,
                        ],
                    ),
            ).to.be.reverted;

            await expect(
                adb.setPhase2MerkleRoots(
                    phase2MerkleTree.map((e) => `0x${e.root}`) as [
                        string,
                        string,
                        string,
                        string,
                    ],
                ),
            ).to.not.be.reverted;
            expect(await adb.phase2MerkleRoots(0)).to.be.equal(
                `0x${phase2MerkleTree[0].root}`,
            );
            expect(await adb.phase2MerkleRoots(1)).to.be.equal(
                `0x${phase2MerkleTree[1].root}`,
            );
            expect(await adb.phase2MerkleRoots(2)).to.be.equal(
                `0x${phase2MerkleTree[2].root}`,
            );
            expect(await adb.phase2MerkleRoots(3)).to.be.equal(
                `0x${phase2MerkleTree[3].root}`,
            );
        });

        it('Should participate', async () => {
            const { adb, tapOFT, aoTAP, generatePhase1_4Signers } =
                await loadFixture(setupFixture);
            setupEnv(adb, tapOFT);
            const { phase2Users, phase2MerkleTree } = await loadFixture(
                setupADBPhase2Fixtures,
            );

            // register users
            await adb.setPhase2MerkleRoots(
                phase2MerkleTree.map((e) => `0x${e.root}`) as [
                    string,
                    string,
                    string,
                    string,
                ],
            );
            const snapshot = await takeSnapshot();

            const testParticipationByRole = async (role: number) => {
                await snapshot.restore();

                const rndPhase2User = {
                    wallet: await loadPhase2UserWallet(
                        adb,
                        phase2Users[role].signers[0].pk,
                    ),
                    role: phase2Users[role].role,
                    merkleProof: phase2MerkleTree[role].merkleTree.getHexProof(
                        hre.ethers.utils.keccak256(
                            phase2Users[role].signers[0].address,
                        ),
                    ),
                };

                //---- Can't participate if epoch is not started or finished
                await expect(
                    adb
                        .connect(rndPhase2User.wallet)
                        .participate(
                            encodePhase2Data(
                                rndPhase2User.role,
                                rndPhase2User.merkleProof,
                            ),
                        ),
                ).to.be.reverted;

                //---- test adb participation
                await newEpoch(adb);
                expect(await adb.epoch()).to.be.eq(BN(1));
                await newEpoch(adb);
                expect(await adb.epoch()).to.be.eq(BN(2));
                expect(
                    await adb.userParticipation(
                        rndPhase2User.wallet.address,
                        20 + role,
                    ),
                ).to.be.false; // Check if user is registered

                await expect(
                    adb
                        .connect(rndPhase2User.wallet)
                        .participate(
                            encodePhase2Data(
                                [0, 1, 2, 3].filter((e) => e != role)[0],
                                rndPhase2User.merkleProof,
                            ),
                        ),
                ).to.reverted; // False proof with wrong role

                await expect(
                    adb
                        .connect(rndPhase2User.wallet)
                        .participate(
                            encodePhase2Data(
                                rndPhase2User.role,
                                phase2MerkleTree[
                                    [0, 1, 2, 3].filter((e) => e != role)[0]
                                ].merkleTree.getHexProof(
                                    hre.ethers.utils.keccak256(
                                        phase2Users[role].signers[0].address,
                                    ),
                                ),
                            ),
                        ),
                ).to.reverted; // False proof with wrong tree

                await expect(
                    adb
                        .connect(rndPhase2User.wallet)
                        .participate(
                            encodePhase2Data(
                                rndPhase2User.role,
                                phase2MerkleTree[role].merkleTree.getHexProof(
                                    hre.ethers.utils.keccak256(
                                        phase2Users[role].signers[1].address,
                                    ),
                                ),
                            ),
                        ),
                ).to.reverted; // False proof with wrong address

                await expect(
                    adb
                        .connect(rndPhase2User.wallet)
                        .participate(
                            encodePhase2Data(
                                rndPhase2User.role,
                                rndPhase2User.merkleProof,
                            ),
                        ),
                )
                    .to.emit(adb, 'Participate')
                    .withArgs(2, 1);

                await expect(
                    adb
                        .connect(rndPhase2User.wallet)
                        .participate(
                            encodePhase2Data(
                                rndPhase2User.role,
                                rndPhase2User.merkleProof,
                            ),
                        ),
                ).to.reverted;

                expect(
                    await adb.userParticipation(
                        rndPhase2User.wallet.address,
                        20 + role,
                    ),
                ).to.be.true; // Check if user is registered

                // Check minted aoTAP
                const aoTAPTokenID = await aoTAP.mintedAOTAP();
                const aoTAPOption = await aoTAP.options(aoTAPTokenID);

                const amountPerUser = [200, 190, 200, 190].map((e) =>
                    BN(1e18).mul(e),
                );
                const discountPerUser = [50, 40, 40, 33].map((e) =>
                    BN(e * 1e4),
                );

                expect(aoTAPOption.amount).to.be.eq(amountPerUser[role]); // 200 per user for role 0
                expect(aoTAPOption.expiry).to.be.eq(
                    (await adb.lastEpochUpdate()).add(
                        await adb.EPOCH_DURATION(),
                    ),
                ); // 1 epoch after last epoch update
                expect(aoTAPOption.discount).to.be.eq(discountPerUser[role]);
            };

            await testParticipationByRole(0);
            await testParticipationByRole(1);
            await testParticipationByRole(2);
            await testParticipationByRole(3);
        });
    });

    describe('Phase 3', () => {
        it('Should participate', async () => {
            const {
                adb,
                tapOFT,
                aoTAP,
                pcnft,
                generatePhase3Data,
                generatePhase3Signers,
                getEncodedAddressOfToken,
            } = await loadFixture(setupFixture);

            setupEnv(adb, tapOFT);
            await newEpoch(adb);
            await newEpoch(adb);
            await newEpoch(adb);
            expect(await adb.epoch()).to.be.eq(BN(3));

            const users = await generatePhase3Signers(pcnft);
            const [rndPhase3User] = users;

            //---- test adb participation
            expect(await adb.userParticipation(getEncodedAddressOfToken(1), 3))
                .to.be.false; // Check has PCNFT

            await expect(
                adb.connect(rndPhase3User).participate(generatePhase3Data(1)),
            )
                .to.emit(adb, 'Participate')
                .withArgs(3, 1);

            expect(await adb.userParticipation(getEncodedAddressOfToken(1), 3))
                .to.be.true; // Check if user is registered

            await expect(
                adb.connect(rndPhase3User).participate(generatePhase3Data(1)),
            ).to.reverted;

            // Check minted aoTAP
            const aoTAPTokenID = await aoTAP.mintedAOTAP();
            const aoTAPOption = await aoTAP.options(aoTAPTokenID);

            expect(aoTAPOption.amount).to.be.eq(BN(714).mul((1e18).toString())); // 200 per user for role 0
            expect(aoTAPOption.expiry).to.be.eq(
                (await adb.lastEpochUpdate()).add(await adb.EPOCH_DURATION()),
            ); // 1 epoch after last epoch update
            expect(aoTAPOption.discount).to.be.eq(50e4);
        });
    });

    describe('Phase 4', () => {
        it('Should check if the epoch duration changed on epoch 4', async () => {
            const { adb, tapOFT } = await loadFixture(setupFixture);
            setupEnv(adb, tapOFT);

            //---- test adb participation
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.epoch()).to.be.eq(BN(4));
            expect(await adb.EPOCH_DURATION()).to.be.eq(604800); // 7 days
        });

        it('Should send token to owner after 8 epochs', async () => {
            const { adb, tapOFT, users, signer } = await loadFixture(
                setupFixture,
            );
            setupEnv(adb, tapOFT);

            //---- test adb participation
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.EPOCH_DURATION()).to.be.eq(172800); // 2 days
            await newEpoch(adb);
            expect(await adb.epoch()).to.be.eq(BN(4));
            expect(await adb.EPOCH_DURATION()).to.be.eq(604800); // 7 days

            await newEpoch(adb);
            await newEpoch(adb);
            await newEpoch(adb);
            await newEpoch(adb);
            expect(await adb.epoch()).to.be.eq(BN(8));
            await expect(adb.daoRecoverTAP()).to.be.revertedWith(
                'adb: too soon',
            );
            await newEpoch(adb);
            expect(await adb.epoch()).to.be.eq(BN(9));

            await expect(
                adb.connect(users[0]).daoRecoverTAP(),
            ).to.be.revertedWith('Ownable: caller is not the owner');

            await tapOFT.transfer(
                users[0].address,
                await tapOFT.balanceOf(signer.address),
            ); // "Burn" all currently held tokens

            await adb.daoRecoverTAP();
            expect(await tapOFT.balanceOf(adb.address)).to.be.eq(0);
            expect(await tapOFT.balanceOf(adb.owner())).to.be.eq(
                BN((1e18).toString()).mul(2_500_000),
            );
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
                initialAmount: 500_000,
            });
            await adb.registerUserForPhase(
                4,
                users.map((e) => e.wallet.address),
                users.map((e) => e.amount),
            );

            //---- Can't participate if epoch is not started or finished
            await expect(adb.connect(users[0].wallet).participate('0x00')).to.be
                .reverted;

            //---- test adb participation
            await newEpoch(adb);
            await newEpoch(adb);
            await newEpoch(adb);
            await newEpoch(adb);
            expect(await adb.epoch()).to.be.eq(BN(4));

            for (const user of users) {
                const mintedAOTAP = await aoTAP.mintedAOTAP();
                // Participate
                await expect(
                    adb.connect(user.wallet).participate(user.wallet.address),
                )
                    .to.emit(adb, 'Participate')
                    .withArgs(4, mintedAOTAP.add(1));

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
                expect(aoTAPOption.discount).to.be.eq(BN(33e4)); // 33% discount

                // Close eligibility
                expect(await adb.phase1Users(user.wallet.address)).to.be.eq(0);
                await expect(
                    adb.connect(user.wallet).participate(user.wallet.address),
                ).to.reverted;
            }
        });
    });

    it('Should get correct OTC details', async () => {
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
        ).to.be.reverted;

        await expect(
            adb
                .connect(registrations[0].user)
                .getOTCDealDetails(
                    registrations[0].aoTAPTokenID,
                    stableMock.address,
                    registrations[0].aoTAPOption.amount.add(1),
                ),
        ).to.be.reverted;

        await expect(
            adb
                .connect(registrations[0].user)
                .getOTCDealDetails(
                    registrations[0].aoTAPTokenID,
                    stableMock.address,
                    BN((1e18).toString()).sub(1),
                ),
        ).to.be.reverted;

        await time_travel((await adb.EPOCH_DURATION()).toNumber());
        await expect(
            adb
                .connect(registrations[0].user)
                .getOTCDealDetails(
                    registrations[0].aoTAPTokenID,
                    stableMock.address,
                    0,
                ),
        ).to.be.reverted;

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
        ).to.be.rejected;
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
        ).to.be.rejected;
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
        ).to.be.rejected;
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
            await expect(
                adb
                    .connect(users[0].wallet)
                    .exerciseOption(
                        registrations[0].aoTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejected;
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
            ).to.be.rejected;
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
                        BN((1e18).toString()).sub(1),
                    ),
            ).to.be.rejected;

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

            expect(await tapOFT.balanceOf(users[0].wallet.address)).to.be.equal(
                eligibleTapAmount,
            ); // Check TAP transfer to user
            expect(await tapOFT.balanceOf(adb.address)).to.be.equal(
                BN(2_500_000).mul((1e18).toString()).sub(eligibleTapAmount),
            ); // Check TAP subtracted from ADB contract
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
            ).to.be.rejected;
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
            ).to.be.rejected;
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
            ).to.be.rejected;
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
                        BN((1e18).toString()).sub(1),
                    ),
            ).to.be.rejected;

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

            expect(await tapOFT.balanceOf(users[1].wallet.address)).to.be.equal(
                tapAmountWanted,
            ); // Check TAP transfer to user

            expect(await tapOFT.balanceOf(adb.address)).to.be.equal(
                BN(2_500_000)
                    .mul((1e18).toString())
                    .sub(tapAmountWanted)
                    .sub(user1EligibleTapAmount),
            ); // Check TAP subtraction from ADB contract

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

            expect(await tapOFT.balanceOf(users[1].wallet.address)).to.be.equal(
                __fullEligibleTapAMount,
            ); // Check TAP transfer to user

            expect(await tapOFT.balanceOf(adb.address)).to.be.equal(
                BN(2_500_000)
                    .mul((1e18).toString())
                    .sub(__fullEligibleTapAMount)
                    .sub(user1EligibleTapAmount),
            ); // Check TAP subtraction from TAP contract

            expect(await ethMock.balanceOf(adb.address)).to.be.closeTo(
                fullPaymentTokenToSend,
                1,
            ); // Check payment token transfer to adb contract

            // Can't exercise more than eligible
            await expect(
                adb
                    .connect(users[1].wallet)
                    .exerciseOption(
                        registrations[1].aoTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            ).to.be.rejected;
        }
    });
    it('should throw an error if OTC payment is not fully accounted for', async () => {
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

        await adb.setPaymentToken(
            stableMock.address,
            stableMockOracle.address,
            '0x00',
        );

        const otcDetails = await adb
            .connect(users[0].wallet)
            .getOTCDealDetails(
                registrations[0].aoTAPTokenID,
                stableMock.address,
                0,
            );
        await stableMock.mintTo(
            users[0].wallet.address,
            otcDetails.paymentTokenAmount,
        );
        await stableMock
            .connect(users[0].wallet)
            .approve(adb.address, otcDetails.paymentTokenAmount);

        const snapshot = await takeSnapshot();

        await expect(
            adb
                .connect(users[0].wallet)
                .exerciseOption(
                    registrations[0].aoTAPTokenID,
                    stableMock.address,
                    0,
                ),
        ).to.not.be.reverted;

        await snapshot.restore();

        await stableMock.setTransferFee(50); // 0.5% fee
        await stableMock.setFeeRecipient(users[1].wallet.address);
        await expect(
            adb
                .connect(users[0].wallet)
                .exerciseOption(
                    registrations[0].aoTAPTokenID,
                    stableMock.address,
                    0,
                ),
        ).to.be.reverted;
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
        ).to.be.reverted;

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

        expect(await adb.epochTAPValuation()).to.be.equal((33e17).toString());

        await time_travel((await adb.EPOCH_DURATION()).toNumber());
        const tapPrice = BN((1e18).toString()).mul(2);
        await tapOracleMock.set(tapPrice);
        await adb.newEpoch();
        expect(await adb.epochTAPValuation()).to.be.equal(tapPrice);
        expect(await adb.epoch()).to.be.equal(2);
    });

    it('should set payment beneficiary', async () => {
        const { users, adb } = await loadFixture(setupFixture);

        await expect(
            adb.connect(users[0]).setPaymentTokenBeneficiary(users[0].address),
        ).to.be.reverted;
        await adb.setPaymentTokenBeneficiary(users[0].address);
        expect(await adb.paymentTokenBeneficiary()).to.be.equal(
            users[0].address,
        );
    });

    it('should collect payment token', async () => {
        const {
            signer,

            paymentTokenBeneficiary,
            adb,
            tapOFT,
            aoTAP,
            stableMock,
            stableMockOracle,
            generatePhase1_4Signers,
        } = await loadFixture(setupFixture);
        await setupEnv(adb, tapOFT);

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

        const otcDetails = await adb.getOTCDealDetails(
            registrations[0].aoTAPTokenID,
            stableMock.address,
            0,
        );

        // Exercise
        await stableMock.mintTo(
            users[0].wallet.address,
            otcDetails.paymentTokenAmount,
        );

        await stableMock
            .connect(users[0].wallet)
            .approve(adb.address, otcDetails.paymentTokenAmount);
        await adb
            .connect(users[0].wallet)
            .exerciseOption(
                registrations[0].aoTAPTokenID,
                stableMock.address,
                otcDetails.eligibleTapAmount,
            );

        // Collect
        await expect(
            adb
                .connect(users[0].wallet)
                .collectPaymentTokens([stableMock.address]),
        ).to.be.rejected;
        await adb.collectPaymentTokens([stableMock.address]);
        expect(await stableMock.balanceOf(adb.address)).to.be.equal(0);
        expect(
            await stableMock.balanceOf(paymentTokenBeneficiary.address),
        ).to.be.equal(otcDetails.paymentTokenAmount);
    });
});
