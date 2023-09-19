import {
    loadFixture,
    takeSnapshot,
    time,
} from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import {
    BN,
    aml_computeAverageMagnitude,
    aml_computeTarget,
    aml_computeMagnitude,
    getERC721PermitSignature,
    time_travel,
} from '../test.utils';
import {
    OTAP,
    TapiocaOptionBroker,
    TapiocaOptionLiquidityProvision,
    TapOFT,
} from '../../typechain';
import { BigNumber } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
    ERC20Mock,
    ERC20Mock__factory,
    OracleMock__factory,
} from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';
import { YieldBox } from '../../gitsub_tapioca-sdk/src/typechain/YieldBox';
import { setupFixture } from './fixtures';
import { TapiocaOptionBrokerMock } from '../../typechain/contracts/options/mocks/TapiocaOptionBrokerMock';

describe('TapiocaOptionBroker', () => {
    const setupEnv = async (
        tOB: TapiocaOptionBroker,
        tOLP: TapiocaOptionLiquidityProvision,
        tapOFT: TapOFT,
        sglTokenMock: ERC20Mock,
        sglTokenMockAsset: BigNumber,
        sglTokenMock2: ERC20Mock,
        sglTokenMock2Asset: BigNumber,
    ) => {
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);
        await tOLP.registerSingularity(
            sglTokenMock.address,
            sglTokenMockAsset,
            0,
        );
        await tOLP.registerSingularity(
            sglTokenMock2.address,
            sglTokenMock2Asset,
            0,
        );
    };

    const lockAndParticipate = async (
        signer: SignerWithAddress,
        amount: number,
        lockDuration: number,
        tOLP: TapiocaOptionLiquidityProvision,
        tOB: TapiocaOptionBroker,
        oTAP: OTAP,
        yieldBox: YieldBox,
        sglTokenMock: ERC20Mock,
        sglTokenMockAsset: BigNumber,
    ) => {
        await sglTokenMock.connect(signer).freeMint(amount);
        await sglTokenMock.connect(signer).approve(yieldBox.address, amount);
        await yieldBox
            .connect(signer)
            .depositAsset(
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
        await yieldBox.connect(signer).setApprovalForAll(tOLP.address, true);
        const lockTx = await tOLP
            .connect(signer)
            .lock(signer.address, sglTokenMock.address, lockDuration, ybAmount);
        const tOLPTokenID = await tOLP.tokenCounter();

        await tOLP.connect(signer).approve(tOB.address, tOLPTokenID);
        await tOB.connect(signer).participate(tOLPTokenID);
        const oTAPTokenID = await oTAP.mintedOTAP();

        const oTAPOption = await oTAP.options(oTAPTokenID);

        return {
            tOLPTokenID,
            lockTx,
            ybAmount,
            amount,
            lockDuration,
            oTAPTokenID,
            oTAPOption,
        };
    };

    it('should test tOB discount', async () => {
        const { tOB, oTAP, tapOFT, tOLP, signer } = await loadFixture(
            setupFixture,
        );

        const discount = await tOB.getDiscountedPaymentAmount(
            ethers.utils.parseEther('1'),
            ethers.utils.parseEther('1'),
            5e3,
            18,
        );
        expect(discount.eq(1)).to.be.true;
    });

    it('should claim oTAP and TAP', async () => {
        const { tOB, oTAP, tapOFT } = await loadFixture(setupFixture);

        await tOB.oTAPBrokerClaim();
        expect(await oTAP.broker()).to.be.eq(tOB.address);

        await tapOFT.setMinter(tOB.address);
        expect(await tapOFT.minter()).to.be.eq(tOB.address);
    });

    it('should participate', async () => {
        const {
            signer,
            users,
            tOLP,
            tOB,
            tapOFT,
            oTAP,
            sglTokenMock,
            sglTokenMockAsset,
            yieldBox,
        } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 1e8;
        let lockDuration = BN(4);
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
        const snapshot = await takeSnapshot();
        const lockTx = await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            ybAmount,
        );
        const tokenID = await tOLP.tokenCounter();

        // test tOB participation
        await expect(tOB.participate(29)).to.be.revertedWith(
            'tOB: Position is not active',
        ); // invalid/inexistent tokenID

        await expect(tOB.participate(tokenID)).to.be.revertedWith(
            'tOB: Duration too short',
        ); // Too short lock duration

        await snapshot.restore();
        lockDuration = await tOB.EPOCH_DURATION();
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            ybAmount,
        );

        await expect(
            tOB.connect(users[0]).participate(tokenID),
        ).to.be.revertedWith('tOB: Not approved or owner'); // Not owner

        const prevPoolState = await tOB.twAML(sglTokenMockAsset);

        await tOLP.approve(tOB.address, tokenID);
        await tOB.participate(tokenID);
        const participation = await tOB.participants(tokenID);

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
        const newPoolState = await tOB.twAML(sglTokenMockAsset);

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
            lockDuration.add(
                (await hre.ethers.provider.getBlock(lockTx.blockNumber!))
                    .timestamp,
            ),
        );

        /// Check transfer of tOLP
        await expect(tOB.participate(tokenID)).to.be.revertedWith(
            'tOB: Not approved or owner',
        );
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(tOB.address);

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
        await tOLP.connect(user).approve(tOB.address, _tokenID);
        await tOB.connect(user).participate(_tokenID);

        expect(await tOB.twAML(sglTokenMockAsset)).to.be.deep.equal(
            newPoolState,
        ); // No change in AML state
    });

    it('should exit position', async () => {
        const {
            signer,
            users,
            tOLP,
            tOB,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            yieldBox,
            oTAP,
        } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

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
            tOB.exitPosition((await oTAP.mintedOTAP()).add(1)),
        ).to.be.revertedWith('tOB: oTAP position does not exist');
        await snapshot.restore();

        // Participate
        await tOLP.approve(tOB.address, tokenID);
        await tOB.participate(tokenID);
        const oTAPTknID = await oTAP.mintedOTAP();
        const participation = await tOB.participants(tokenID);
        const prevPoolState = await tOB.twAML(sglTokenMockAsset);

        // Test exit
        await expect(tOB.exitPosition(oTAPTknID)).to.be.revertedWith(
            'tOB: Lock not expired',
        );
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(tOB.address);

        await time.increase(lockDuration);
        await oTAP.approve(tOB.address, oTAPTknID);
        await tOB.exitPosition(oTAPTknID);

        // Check tokens transfer
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(signer.address);
        expect(await oTAP.exists(oTAPTknID)).to.be.false;

        // Check AML update
        const newPoolState = await tOB.twAML(sglTokenMockAsset);

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
        await tOLP.connect(user).approve(tOB.address, _tokenID);
        await tOB.connect(user).participate(_tokenID);

        await time.increase(lockDuration);

        const _oTAPTknID = await oTAP.mintedOTAP();
        await oTAP.connect(user).approve(tOB.address, _oTAPTknID);
        await tOB.connect(user).exitPosition(_oTAPTknID);

        expect(await tOB.twAML(sglTokenMockAsset)).to.be.deep.equal(
            newPoolState,
        ); // No change in AML state
        expect((await tOB.twAML(sglTokenMockAsset)).cumulative).to.be.equal(0);
    });

    it('should enter and exit multiple positions', async () => {
        const {
            signer,
            tOLP,
            tOB,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            yieldBox,
            oTAP,
        } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

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
            tOB.exitPosition((await oTAP.mintedOTAP()).add(1)),
        ).to.be.revertedWith('tOB: oTAP position does not exist');
        await snapshot.restore();

        // Participate
        await tOLP.approve(tOB.address, tokenID);
        await tOLP.approve(tOB.address, tokenID.sub(1));
        await tOLP.approve(tOB.address, tokenID.sub(2));
        await tOB.participate(tokenID);
        await tOB.participate(tokenID.sub(1));
        await tOB.participate(tokenID.sub(2));

        const oTAPTknID = await oTAP.mintedOTAP();

        await time.increase(lockDuration);

        {
            // Exit 1
            await oTAP.approve(tOB.address, oTAPTknID);
            await tOB.exitPosition(oTAPTknID);
        }

        {
            // Exit 2
            await oTAP.approve(tOB.address, oTAPTknID.sub(1));
            await tOB.exitPosition(oTAPTknID.sub(1));
        }

        {
            // Exit 3
            await oTAP.approve(tOB.address, oTAPTknID.sub(2));
            await tOB.exitPosition(oTAPTknID.sub(2));
        }
    });

    it('should set a payment token', async () => {
        const { tOB, users, stableMock, stableMockOracle } = await loadFixture(
            setupFixture,
        );

        await expect(
            tOB
                .connect(users[0])
                .setPaymentToken(
                    stableMock.address,
                    stableMockOracle.address,
                    '0x00',
                ),
        ).to.be.revertedWith('Ownable: caller is not the owner');

        await expect(
            tOB.setPaymentToken(
                stableMock.address,
                stableMockOracle.address,
                '0x00',
            ),
        )
            .to.emit(tOB, 'SetPaymentToken')
            .withArgs(stableMock.address, stableMockOracle.address, '0x00');

        const paymentToken = await tOB.paymentTokens(stableMock.address);
        expect(paymentToken.oracle).to.be.equal(stableMockOracle.address);
        expect(paymentToken.oracleData).to.be.equal('0x00');

        await expect(
            tOB.setPaymentToken(
                stableMock.address,
                hre.ethers.constants.AddressZero,
                '0x00',
            ),
        )
            .to.emit(tOB, 'SetPaymentToken')
            .withArgs(
                stableMock.address,
                hre.ethers.constants.AddressZero,
                '0x00',
            );

        expect(
            (await tOB.paymentTokens(stableMock.address)).oracle,
        ).to.be.equal(hre.ethers.constants.AddressZero);
    });

    it('should increment the epoch', async () => {
        const {
            tOB,
            tapOFT,
            tOLP,
            sglTokenMock,
            sglTokenMockAsset,
            tapOracleMock,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // No singularities
        await expect(tOB.newEpoch()).to.be.revertedWith(
            'tOB: No active singularities',
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
        const txNewEpoch = await tOB.newEpoch();
        expect(await tOB.epoch()).to.be.equal(1);

        const txNewEpochTimestamp = (
            await hre.ethers.provider.getBlock(txNewEpoch.blockNumber!)
        ).timestamp;
        expect(await tOB.lastEpochUpdate()).to.be.equal(
            await tOB.timestampToWeek(txNewEpochTimestamp),
        );
        expect(await tOB.epochTAPValuation()).to.be.equal(tapPrice);

        const emittedTAP = await tapOFT.getCurrentWeekEmission();

        // Check TAP minting for 1 SGL asset
        expect(emittedTAP.gt(0)).to.be.true;
        expect(await tOB.singularityGauges(1, sglTokenMockAsset)).to.be.equal(
            emittedTAP,
        );

        // Check TAP minting for 2 SGL assets with equal weights
        await snapshot.restore();
        await tOLP.registerSingularity(
            sglTokenMock2.address,
            sglTokenMock2Asset,
            0,
        );
        await tOB.newEpoch();
        expect(await tOB.singularityGauges(1, sglTokenMockAsset)).to.be.equal(
            emittedTAP.div(2),
        );
        expect(await tOB.singularityGauges(1, sglTokenMock2Asset)).to.be.equal(
            emittedTAP.div(2),
        );

        // Check TAP minting for 2 SGL assets with different weights
        await snapshot.restore();
        await tOLP.registerSingularity(
            sglTokenMock2.address,
            sglTokenMock2Asset,
            2,
        );
        await tOB.newEpoch();
        expect(await tOB.singularityGauges(1, sglTokenMockAsset)).to.be.equal(
            emittedTAP.div(3),
        );
        expect(await tOB.singularityGauges(1, sglTokenMock2Asset)).to.be.equal(
            emittedTAP.mul(2).div(3),
        );
    });

    it('should return correct OTC details', async () => {
        const {
            users,
            yieldBox,
            tOB,
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
            tOB,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await tOB.newEpoch();

        await tOB.setPaymentToken(
            stableMock.address,
            stableMockOracle.address,
            '0x00',
        );
        await tOB.setPaymentToken(
            ethMock.address,
            ethMockOracle.address,
            '0x00',
        );
        const userLock1 = await lockAndParticipate(
            users[0],
            3e8,
            3600,
            tOLP,
            tOB,
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
            tOB,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );

        const epoch = await tOB.epoch();

        const snapshot = await takeSnapshot();

        /// FULL ELIGIBLE STABLE

        // Exercise for full eligible TAP with 1e6 decimals stable, 50% discount
        {
            const eligibleTapAmount = userLock1.ybAmount
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await stableMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment
                .sub(discount)
                .div((1e12).toString());

            const otcDetails = await tOB
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
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await stableMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment
                .mul(userLock2.oTAPOption.discount)
                .div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await tOB
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
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await ethMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await tOB
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
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await ethMockOracle.get('0x00'))[1],
            ); // USDC price at 1
            const discount = rawPayment
                .mul(userLock2.oTAPOption.discount)
                .div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await tOB
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

            const otcDetails = await tOB
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

            const otcDetails = await tOB
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

            const otcDetails = await tOB
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

            const otcDetails = await tOB
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
            tOB,
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
            tOB,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await tOB.newEpoch();

        await tOB.setPaymentToken(
            stableMock.address,
            stableMockOracle.address,
            '0x00',
        );
        await tOB.setPaymentToken(
            ethMock.address,
            ethMockOracle.address,
            '0x00',
        );
        const userLock1 = await lockAndParticipate(
            users[0],
            3e8,
            1_209_600, // 2 week
            tOLP,
            tOB,
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
            tOB,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );

        // Check requirements
        const _otcDetails = await tOB
            .connect(users[0])
            .getOTCDealDetails(userLock1.oTAPTokenID, stableMock.address, 0);
        await expect(
            tOB
                .connect(users[1])
                .exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0),
        ).to.be.rejectedWith('tOB: Not approved or owner');
        await expect(
            tOB
                .connect(users[0])
                .exerciseOption(
                    userLock1.oTAPTokenID,
                    stableMock.address,
                    _otcDetails.eligibleTapAmount.add(1),
                ),
        ).to.be.rejectedWith('tOB: Too high');
        await expect(
            tOB
                .connect(users[0])
                .exerciseOption(
                    userLock1.oTAPTokenID,
                    stableMock.address,
                    BN((1e18).toString()).sub(1),
                ),
        ).to.be.rejectedWith('tOB: Too low');
        const snapshot = await takeSnapshot();
        await tOB.setPaymentToken(
            stableMock.address,
            hre.ethers.constants.AddressZero,
            '0x00',
        );
        await expect(
            tOB
                .connect(users[0])
                .exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0),
        ).to.be.rejectedWith('tOB: Payment token not supported');
        await snapshot.restore();
        await time.increase(userLock1.lockDuration);
        await expect(
            tOB
                .connect(users[0])
                .exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0),
        ).to.be.rejectedWith('tOB: Option expired');
        await snapshot.restore();

        // Gauge emission check
        const epoch = await tOB.epoch();
        const sglGaugeTokenMock1 = (await tapOFT.getCurrentWeekEmission())
            .mul(2)
            .div(3);
        const sglGaugeTokenMock2 = (await tapOFT.getCurrentWeekEmission())
            .mul(1)
            .div(3);
        expect(await tOB.singularityGauges(epoch, sglTokenMockAsset)).to.equal(
            sglGaugeTokenMock1,
        );
        expect(await tOB.singularityGauges(epoch, sglTokenMock2Asset)).to.equal(
            sglGaugeTokenMock2,
        );

        // Exercise option for user 1 for full eligible TAP amount
        let user1EligibleTapAmount;
        let user1PaymentAmount;
        {
            const otcDetails = await tOB
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
                tOB
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await stableMock.mintTo(users[0].address, paymentTokenToSend);
            await expect(
                tOB
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        0,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await stableMock
                .connect(users[0])
                .approve(tOB.address, paymentTokenToSend);

            // Exercise option checks
            await expect(
                tOB
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        eligibleTapAmount,
                    ),
            )
                .to.emit(tOB, 'ExerciseOption')
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
            expect(await stableMock.balanceOf(tOB.address)).to.be.equal(
                paymentTokenToSend,
            ); // Check payment token transfer to TOB contract

            expect(
                await tOB.oTAPCalls(userLock1.oTAPTokenID, epoch),
            ).to.be.equal(eligibleTapAmount);

            // end
            await expect(
                tOB
                    .connect(users[0])
                    .exerciseOption(
                        userLock1.oTAPTokenID,
                        stableMock.address,
                        eligibleTapAmount,
                    ),
            ).to.be.rejectedWith('tOB: Too high');
        }

        let user2EligibleTapAmount;
        let user2PaymentAmount;
        // Exercise option for user 2 for half eligible TAP amount
        {
            const { eligibleTapAmount: __fullEligibleTapAMount } = await tOB
                .connect(users[1])
                .getOTCDealDetails(userLock2.oTAPTokenID, ethMock.address, 0);
            const tapAmountWanted = __fullEligibleTapAMount.div(2);
            const { paymentTokenAmount: fullPaymentTokenToSend } = await tOB
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
                tOB
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await ethMock.mintTo(users[1].address, fullPaymentTokenToSend);

            await expect(
                tOB
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            ).to.be.rejectedWith('ERC20: insufficient allowance');
            await ethMock
                .connect(users[1])
                .approve(tOB.address, fullPaymentTokenToSend);

            // Exercise option checks
            await expect(
                tOB
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            )
                .to.emit(tOB, 'ExerciseOption')
                .withArgs(
                    epoch,
                    users[1].address,
                    ethMock.address,
                    userLock2.oTAPTokenID,
                    tapAmountWanted,
                ); // Successful exercise

            expect(
                await tOB.oTAPCalls(userLock2.oTAPTokenID, epoch),
            ).to.be.equal(tapAmountWanted); // Check exercised amount has been updated

            expect(await tapOFT.balanceOf(users[1].address)).to.be.equal(
                tapAmountWanted,
            ); // Check TAP transfer to user

            expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal(
                (await tapOFT.mintedInWeek(epoch))
                    .sub(tapAmountWanted)
                    .sub(user1EligibleTapAmount),
            ); // Check TAP subtraction from TAP contract

            expect(await ethMock.balanceOf(tOB.address)).to.be.equal(
                halfPaymentTokenToSend,
            ); // Check payment token transfer to TOB contract

            // Exercise option for user 2 for remaining eligible TAP amount
            await expect(
                tOB
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            )
                .to.emit(tOB, 'ExerciseOption')
                .withArgs(
                    epoch,
                    users[1].address,
                    ethMock.address,
                    userLock2.oTAPTokenID,
                    tapAmountWanted,
                ); // Successful exercise

            expect(
                await tOB.oTAPCalls(userLock2.oTAPTokenID, epoch),
            ).to.be.equal(__fullEligibleTapAMount); // Check exercised amount has been updated

            expect(await tapOFT.balanceOf(users[1].address)).to.be.equal(
                __fullEligibleTapAMount,
            ); // Check TAP transfer to user

            expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal(
                (await tapOFT.mintedInWeek(epoch))
                    .sub(__fullEligibleTapAMount)
                    .sub(user1EligibleTapAmount),
            ); // Check TAP subtraction from TAP contract

            expect(await ethMock.balanceOf(tOB.address)).to.be.closeTo(
                fullPaymentTokenToSend,
                1,
            ); // Check payment token transfer to TOB contract

            // Can't exercise option again for this epoch
            await expect(
                tOB
                    .connect(users[1])
                    .exerciseOption(
                        userLock2.oTAPTokenID,
                        ethMock.address,
                        tapAmountWanted,
                    ),
            ).to.be.rejectedWith('tOB: Too high');
        }

        // Jump to next epoch
        await time_travel(604800); // 1 week
        await tOB.newEpoch();

        // Exercise option for user 1 for remaining eligible TAP amount
        await stableMock.mintTo(users[0].address, user1PaymentAmount);
        await stableMock
            .connect(users[0])
            .approve(tOB.address, user1PaymentAmount);
        await expect(
            tOB
                .connect(users[0])
                .exerciseOption(
                    userLock1.oTAPTokenID,
                    stableMock.address,
                    user1EligibleTapAmount,
                ),
        )
            .to.emit(tOB, 'ExerciseOption')
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
            .approve(tOB.address, user2PaymentAmount);
        await expect(
            tOB
                .connect(users[1])
                .exerciseOption(
                    userLock2.oTAPTokenID,
                    ethMock.address,
                    user2EligibleTapAmount,
                ),
        )
            .to.emit(tOB, 'ExerciseOption')
            .withArgs(
                epoch.add(1),
                users[1].address,
                ethMock.address,
                userLock2.oTAPTokenID,
                user2EligibleTapAmount,
            ); // Successful exercise
    });

    it('should set payment beneficiary', async () => {
        const { users, tOB } = await loadFixture(setupFixture);

        await expect(
            tOB.connect(users[0]).setPaymentTokenBeneficiary(users[0].address),
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await tOB.setPaymentTokenBeneficiary(users[0].address);
        expect(await tOB.paymentTokenBeneficiary()).to.be.equal(
            users[0].address,
        );
    });

    it('should collect payment token', async () => {
        const {
            signer,
            users,
            paymentTokenBeneficiary,
            yieldBox,
            tOB,
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
            tOB,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await tOB.newEpoch();

        await tOB.setPaymentToken(
            stableMock.address,
            stableMockOracle.address,
            '0x00',
        );
        const userLock1 = await lockAndParticipate(
            users[0],
            3e8,
            3600,
            tOLP,
            tOB,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );
        const otcDetails = await tOB.getOTCDealDetails(
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
            .approve(tOB.address, otcDetails.paymentTokenAmount);
        await tOB
            .connect(users[0])
            .exerciseOption(
                userLock1.oTAPTokenID,
                stableMock.address,
                otcDetails.eligibleTapAmount,
            );

        // Collect
        await expect(
            tOB.connect(users[0]).collectPaymentTokens([stableMock.address]),
        ).to.be.rejectedWith('Ownable: caller is not the owner');
        await tOB.collectPaymentTokens([stableMock.address]);
        expect(await stableMock.balanceOf(tOB.address)).to.be.equal(0);
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
            tOB,
            tapOFT,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);
        await setupEnv(
            tOB,
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
            tOB,
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

    it('Add and remove the correct amount of average magnitude to the cumulative', async () => {
        const {
            signer,
            tOLP,
            tOB,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            yieldBox,
            oTAP,
        } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 3e10;
        const lockDurationA = 10;
        const lockDurationB = 100;
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
        //A (short less impact)
        // console.log(ybAmount);
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDurationA,
            ybAmount.div(100),
        );
        //B (long, big impact)
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDurationB,
            ybAmount.div(2),
        );
        const tokenID = await tOLP.tokenCounter();
        const snapshot = await takeSnapshot();
        // console.log(
        //     'A Duration: ',
        //     lockDurationA,
        //     ' B Duration: ',
        //     lockDurationB,
        // );
        // Just A Participate
        // console.log('Just A participation');
        await tOLP.approve(tOB.address, tokenID.sub(1));
        await tOB.participate(tokenID.sub(1));
        const participationA = await tOB.participants(tokenID.sub(1));
        const oTAPTknID = await oTAP.mintedOTAP();
        await time.increase(lockDurationA);
        const prevPoolState = await tOB.twAML(sglTokenMockAsset);
        // console.log('[B4] Just A Cumulative: ', await prevPoolState.cumulative);
        // console.log('[B4] Just A Average: ', participationA.averageMagnitude);
        await oTAP.approve(tOB.address, oTAPTknID);
        await tOB.exitPosition(oTAPTknID);
        // console.log('Exit A position');
        const newPoolState = await tOB.twAML(sglTokenMockAsset);
        // console.log('[A4] Just A Cumulative: ', await newPoolState.cumulative);
        // console.log(
        //     '[A4] Just A Average: ',
        //     await participationA.averageMagnitude,
        // );

        //Both Participations
        // console.log();
        // console.log('Run both participation---');
        const ctime1 = new Date();
        // console.log('Time: ', ctime1);
        //A and B Participate
        await snapshot.restore();
        //Before everything
        const initPoolState = await tOB.twAML(sglTokenMockAsset);
        // console.log(
        //     '[IN] Initial Cumulative: ',
        //     await initPoolState.cumulative,
        // );
        //First participate A
        await tOLP.approve(tOB.address, tokenID.sub(1));
        await tOB.participate(tokenID.sub(1));
        const xparticipationA = await tOB.participants(tokenID.sub(1));
        const ATknID = await oTAP.mintedOTAP();
        // console.log('Participate A (smaller weight)');
        // console.log('[ID] A Token ID: ', ATknID);
        const xprevPoolState = await tOB.twAML(sglTokenMockAsset);
        // console.log(
        //     '[B4] Both A Cumulative: ',
        //     await xprevPoolState.cumulative,
        // );
        // console.log(
        //     '[B4] Both A Average: ',
        //     await xparticipationA.averageMagnitude,
        // );
        // console.log();

        //Time skip to half A's duration
        await time.increase(5);
        const ctime2 = new Date();
        // console.log('Participate B (larger weight), Time(+5): ', ctime2);

        //Participate B
        await tOLP.approve(tOB.address, tokenID);
        await tOB.participate(tokenID);
        const xparticipationB = await tOB.participants(tokenID);
        const BTknID = await oTAP.mintedOTAP();
        // console.log('[ID] B Token ID: ', ATknID);
        const xbothPoolState = await tOB.twAML(sglTokenMockAsset);
        // console.log(
        //     '[B4] Both AB Cumulative: ',
        //     await xbothPoolState.cumulative,
        // );
        // console.log(
        //     '[B4] Both B Average: ',
        //     await xparticipationB.averageMagnitude,
        // );

        //Time skip end A
        await time.increase(6);
        await oTAP.approve(tOB.address, ATknID);
        await tOB.exitPosition(ATknID);
        const exitAPoolState = await tOB.twAML(sglTokenMockAsset);
        const ctime3 = new Date();
        // console.log();
        // console.log(
        //     'Exit A (Dispraportionate Weight, Time(+6 Expire A): ',
        //     ctime3,
        // );
        // console.log(
        //     '[!X!] Just B Cumulative: ',
        //     await exitAPoolState.cumulative,
        // );
        // console.log('[A4] Just B Average: ', xparticipationB.averageMagnitude);
        expect(exitAPoolState.cumulative).to.be.equal(50);

        //TIme skip end B
        await time.increase(lockDurationB);
        await oTAP.approve(tOB.address, BTknID);
        await tOB.exitPosition(BTknID);
        const exitBPoolState = await tOB.twAML(sglTokenMockAsset);
        const ctime4 = new Date();
        // console.log('Exit B, Time(+100 Expire B): ', ctime4);
        // console.log('[A4] END Cumulative: ', await exitBPoolState.cumulative);
        expect(exitBPoolState.cumulative).to.be.equal(0);
    });

    it('Should support decimals >18', async () => {
        const {
            signer,
            users,
            yieldBox,
            tOB,
            tapOFT,
            tOLP,
            oTAP,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);

        await setupEnv(
            tOB,
            tOLP,
            tapOFT,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        );
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await tOB.newEpoch();

        const ERC20Mock = new ERC20Mock__factory(signer);
        const paymentTokenMock = await ERC20Mock.deploy(
            'paymentTokenMock',
            'PTM',
            0,
            24,
            signer.address,
        );
        await paymentTokenMock.updateMintLimit(hre.ethers.constants.MaxUint256);

        const OracleMock = new OracleMock__factory(signer);
        const paymentTokenOracleMock = await OracleMock.deploy(
            'paymentTokenOracleMock',
            'PTOM',
            BN(10).pow(24).toString(),
        );
        await tOB.setPaymentToken(
            paymentTokenMock.address,
            paymentTokenOracleMock.address,
            '0x00',
        );

        const userLock1 = await lockAndParticipate(
            users[0],
            3e8,
            3600,
            tOLP,
            tOB,
            oTAP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        );

        const epoch = await tOB.epoch();

        // Exercise for 10e18 TAP with 1e24 decimals stable, 50% discount
        {
            const eligibleTapAmount = BN(10e18);
            const otcDealAmountInUSD = BN(33e17).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div(
                (await paymentTokenOracleMock.get('0x00'))[1],
            );
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount).mul(1e6); // 24 - 18

            const otcDetails = await tOB
                .connect(users[0])
                .getOTCDealDetails(
                    userLock1.oTAPTokenID,
                    paymentTokenMock.address,
                    eligibleTapAmount,
                );

            expect(otcDetails.paymentTokenAmount).to.be.equal(
                paymentTokenToSend,
            );
        }
    });
});
