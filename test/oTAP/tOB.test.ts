import { loadFixture, takeSnapshot, time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { setupFixture } from './fixtures';
import hre, { network } from 'hardhat';
import { aml_computeAverageMagnitude, aml_computeDiscount, aml_computeMagnitude, BN, time_travel } from '../test.utils';
import { OTAP, TapiocaOptionBroker, TapiocaOptionLiquidityProvision, TapOFT, YieldBox } from '../../typechain';
import { ERC20Mock } from '../../typechain/ERC20Mock';
import { BigNumber } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

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
        await tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset, 0);
        await tOLP.registerSingularity(sglTokenMock2.address, sglTokenMock2Asset, 0);
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
        await yieldBox.connect(signer).depositAsset(sglTokenMockAsset, signer.address, signer.address, amount, 0);

        const ybAmount = await yieldBox.toAmount(sglTokenMockAsset, await yieldBox.balanceOf(signer.address, sglTokenMockAsset), false);
        await yieldBox.connect(signer).setApprovalForAll(tOLP.address, true);
        const lockTx = await tOLP.connect(signer).lock(signer.address, signer.address, sglTokenMock.address, lockDuration, ybAmount);
        const tOLPTokenID = await tOLP.tokenCounter();

        await tOLP.connect(signer).approve(tOB.address, tOLPTokenID);
        await tOB.connect(signer).participate(tOLPTokenID);
        const oTAPTokenID = await oTAP.mintedOTAP();

        const oTAPOption = await oTAP.options(oTAPTokenID);

        return { tOLPTokenID, lockTx, ybAmount, amount, lockDuration, oTAPTokenID, oTAPOption };
    };

    it('should claim oTAP and TAP', async () => {
        const { tOB, oTAP, tapOFT } = await loadFixture(setupFixture);

        await tOB.oTAPBrokerClaim();
        expect(await oTAP.broker()).to.be.eq(tOB.address);

        await tapOFT.setMinter(tOB.address);
        expect(await tapOFT.minter()).to.be.eq(tOB.address);
    });

    it('should participate', async () => {
        const { signer, users, tOLP, tOB, tapOFT, oTAP, sglTokenMock, sglTokenMockAsset, yieldBox } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 1e8;
        const lockDuration = 10;
        await tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset, 0);

        await sglTokenMock.freeMint(amount);
        await sglTokenMock.approve(yieldBox.address, amount);
        await yieldBox.depositAsset(sglTokenMockAsset, signer.address, signer.address, amount, 0);

        const ybAmount = await yieldBox.toAmount(sglTokenMockAsset, await yieldBox.balanceOf(signer.address, sglTokenMockAsset), false);
        await yieldBox.setApprovalForAll(tOLP.address, true);
        const lockTx = await tOLP.lock(signer.address, signer.address, sglTokenMock.address, lockDuration, ybAmount);
        const tokenID = await tOLP.tokenCounter();

        // test tOB participation
        await expect(tOB.participate(29)).to.be.revertedWith('TapiocaOptionBroker: Position is not active'); // invalid/inexistent tokenID
        await expect(tOB.connect(users[0]).participate(tokenID)).to.be.revertedWith('TapiocaOptionBroker: Not approved or owner'); // Not owner

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
        computedAML.averageMagnitude = aml_computeAverageMagnitude(computedAML.magnitude, BN(0), prevPoolState.totalParticipants.add(1));
        computedAML.discount = aml_computeDiscount(computedAML.magnitude, BN(0), BN(5e4), BN(50e4));

        expect(participation.hasVotingPower).to.be.true;
        expect(participation.averageMagnitude).to.be.equal(computedAML.averageMagnitude);

        // Check AML state
        const newPoolState = await tOB.twAML(sglTokenMockAsset);

        expect(newPoolState.totalParticipants).to.be.equal(prevPoolState.totalParticipants.add(1));
        expect(newPoolState.totalDeposited).to.be.equal(prevPoolState.totalDeposited.add(amount));
        expect(newPoolState.cumulative).to.be.equal(computedAML.magnitude);
        expect(newPoolState.averageMagnitude).to.be.equal(computedAML.averageMagnitude);

        // Check oTAP minting
        const oTAPTokenID = await oTAP.mintedOTAP();

        expect(oTAPTokenID).to.be.equal(1);
        expect(await oTAP.ownerOf(oTAPTokenID)).to.be.equal(signer.address);

        const [, oTAPToken] = await oTAP.attributes(oTAPTokenID);

        expect(oTAPToken.discount).to.be.equal(computedAML.discount);
        expect(oTAPToken.tOLP).to.be.equal(tokenID);
        expect(oTAPToken.expiry).to.be.equal((await hre.ethers.provider.getBlock(lockTx.blockNumber!)).timestamp + lockDuration);

        /// Check transfer of tOLP
        await expect(tOB.participate(tokenID)).to.be.revertedWith('TapiocaOptionBroker: Not approved or owner');
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(tOB.address);

        // Check participation without enough voting power
        const user = users[0];
        const _amount = amount * 0.001 - 1; // < 0.1% of total weights
        await sglTokenMock.mintTo(user.address, _amount);
        await sglTokenMock.connect(user).approve(yieldBox.address, _amount);
        await yieldBox.connect(user).depositAsset(sglTokenMockAsset, user.address, user.address, _amount, 0);
        const _ybAmount = await yieldBox
            .connect(user)
            .toAmount(sglTokenMockAsset, await yieldBox.balanceOf(user.address, sglTokenMockAsset), false);
        await yieldBox.connect(user).setApprovalForAll(tOLP.address, true);
        await tOLP.connect(user).lock(user.address, user.address, sglTokenMock.address, lockDuration, _ybAmount);
        const _tokenID = await tOLP.tokenCounter();
        await tOLP.connect(user).approve(tOB.address, _tokenID);
        await tOB.connect(user).participate(_tokenID);

        expect(await tOB.twAML(sglTokenMockAsset)).to.be.deep.equal(newPoolState); // No change in AML state
    });

    it('should exit position', async () => {
        const { signer, users, tOLP, tOB, tapOFT, sglTokenMock, sglTokenMockAsset, yieldBox, oTAP } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 1e8;
        const lockDuration = 10;
        await tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset, 0);

        await sglTokenMock.freeMint(amount);
        await sglTokenMock.approve(yieldBox.address, amount);
        await yieldBox.depositAsset(sglTokenMockAsset, signer.address, signer.address, amount, 0);

        const ybAmount = await yieldBox.toAmount(sglTokenMockAsset, await yieldBox.balanceOf(signer.address, sglTokenMockAsset), false);
        await yieldBox.setApprovalForAll(tOLP.address, true);
        await tOLP.lock(signer.address, signer.address, sglTokenMock.address, lockDuration, ybAmount);
        const tokenID = await tOLP.tokenCounter();

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(tOB.exitPosition((await oTAP.mintedOTAP()).add(1))).to.be.revertedWith(
            'TapiocaOptionBroker: oTAP position does not exist',
        );
        await snapshot.restore();

        // Participate
        await tOLP.approve(tOB.address, tokenID);
        await tOB.participate(tokenID);
        const oTAPTknID = await oTAP.mintedOTAP();
        const participation = await tOB.participants(tokenID);
        const prevPoolState = await tOB.twAML(sglTokenMockAsset);

        // Test exit
        await expect(tOB.connect(users[0]).exitPosition(oTAPTknID)).to.be.revertedWith('TapiocaOptionBroker: Not approved or owner');
        await expect(tOB.exitPosition(oTAPTknID)).to.be.revertedWith('TapiocaOptionBroker: Lock not expired');
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(tOB.address);

        await time.increase(lockDuration);
        await oTAP.approve(tOB.address, oTAPTknID);
        await tOB.exitPosition(oTAPTknID);

        // Check tokens transfer
        expect(await tOLP.ownerOf(tokenID)).to.be.equal(signer.address);
        expect(await oTAP.exists(oTAPTknID)).to.be.false;

        // Check AML update
        const newPoolState = await tOB.twAML(sglTokenMockAsset);

        expect(newPoolState.totalParticipants).to.be.equal(prevPoolState.totalParticipants.sub(1));
        expect(newPoolState.totalDeposited).to.be.equal(prevPoolState.totalDeposited.sub(amount));
        expect(newPoolState.cumulative).to.be.equal(prevPoolState.cumulative.sub(participation.averageMagnitude));

        // Do not remove participation if not participating
        await snapshot.restore();

        const user = users[0];
        const _amount = amount * 0.001 - 1; // < 0.1% of total weights
        await sglTokenMock.mintTo(user.address, _amount);
        await sglTokenMock.connect(user).approve(yieldBox.address, _amount);
        await yieldBox.connect(user).depositAsset(sglTokenMockAsset, user.address, user.address, _amount, 0);
        const _ybAmount = await yieldBox
            .connect(user)
            .toAmount(sglTokenMockAsset, await yieldBox.balanceOf(user.address, sglTokenMockAsset), false);
        await yieldBox.connect(user).setApprovalForAll(tOLP.address, true);
        await tOLP.connect(user).lock(user.address, user.address, sglTokenMock.address, lockDuration, _ybAmount);
        const _tokenID = await tOLP.tokenCounter();
        await tOLP.connect(user).approve(tOB.address, _tokenID);
        await tOB.connect(user).participate(_tokenID);

        await time.increase(lockDuration);

        const _oTAPTknID = await oTAP.mintedOTAP();
        await oTAP.connect(user).approve(tOB.address, _oTAPTknID);
        await tOB.connect(user).exitPosition(_oTAPTknID);

        expect(await tOB.twAML(sglTokenMockAsset)).to.be.deep.equal(newPoolState); // No change in AML state
        expect((await tOB.twAML(sglTokenMockAsset)).cumulative).to.be.equal(0);
    });

    it('should enter and exit multiple positions', async () => {
        const { signer, tOLP, tOB, tapOFT, sglTokenMock, sglTokenMockAsset, yieldBox, oTAP } = await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 3e8;
        const lockDuration = 10;
        await tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset, 0);

        await sglTokenMock.freeMint(amount);
        await sglTokenMock.approve(yieldBox.address, amount);
        await yieldBox.depositAsset(sglTokenMockAsset, signer.address, signer.address, amount, 0);

        const ybAmount = await yieldBox.toAmount(sglTokenMockAsset, await yieldBox.balanceOf(signer.address, sglTokenMockAsset), false);
        await yieldBox.setApprovalForAll(tOLP.address, true);
        await tOLP.lock(signer.address, signer.address, sglTokenMock.address, lockDuration, ybAmount.div(3));
        await tOLP.lock(signer.address, signer.address, sglTokenMock.address, lockDuration, ybAmount.div(3));
        await tOLP.lock(signer.address, signer.address, sglTokenMock.address, lockDuration, ybAmount.div(3));
        const tokenID = await tOLP.tokenCounter();

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(tOB.exitPosition((await oTAP.mintedOTAP()).add(1))).to.be.revertedWith(
            'TapiocaOptionBroker: oTAP position does not exist',
        );
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
        const { tOB, users, stableMock, stableMockOracle } = await loadFixture(setupFixture);

        await expect(tOB.connect(users[0]).setPaymentToken(stableMock.address, stableMockOracle.address, '0x00')).to.be.revertedWith(
            'Ownable: caller is not the owner',
        );

        await expect(tOB.setPaymentToken(stableMock.address, stableMockOracle.address, '0x00'))
            .to.emit(tOB, 'SetPaymentToken')
            .withArgs(stableMock.address, stableMockOracle.address, '0x00');

        const paymentToken = await tOB.paymentTokens(stableMock.address);
        expect(paymentToken.oracle).to.be.equal(stableMockOracle.address);
        expect(paymentToken.oracleData).to.be.equal('0x00');

        await expect(tOB.setPaymentToken(stableMock.address, hre.ethers.constants.AddressZero, '0x00'))
            .to.emit(tOB, 'SetPaymentToken')
            .withArgs(stableMock.address, hre.ethers.constants.AddressZero, '0x00');

        expect((await tOB.paymentTokens(stableMock.address)).oracle).to.be.equal(hre.ethers.constants.AddressZero);
    });

    it('should increment the epoch', async () => {
        const { tOB, tapOFT, tOLP, sglTokenMock, sglTokenMockAsset, tapOracleMock, sglTokenMock2, sglTokenMock2Asset } = await loadFixture(
            setupFixture,
        );

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // No singularities
        await expect(tOB.newEpoch()).to.be.revertedWith('TapiocaOptionBroker: No active singularities');

        // Register sgl
        const tapPrice = BN(1e18).mul(2);
        await tapOracleMock.setRate(tapPrice);
        await tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset, 0);

        const snapshot = await takeSnapshot();
        // Check epoch update
        const txNewEpoch = await tOB.newEpoch();
        expect(await tOB.epoch()).to.be.equal(1);
        expect(await tOB.lastEpochUpdate()).to.be.equal((await hre.ethers.provider.getBlock(txNewEpoch.blockNumber!)).timestamp);
        expect(await tOB.epochTAPValuation()).to.be.equal(tapPrice);

        const tapOFTBalance = await tapOFT.balanceOf(tapOFT.address);

        // Check TAP minting for 1 SGL asset
        expect(tapOFTBalance.gt(0)).to.be.true;
        expect(await tOB.singularityGauges(1, sglTokenMockAsset)).to.be.equal(tapOFTBalance);

        // Check TAP minting for 2 SGL assets with equal weights
        await snapshot.restore();
        await tOLP.registerSingularity(sglTokenMock2.address, sglTokenMock2Asset, 0);
        await tOB.newEpoch();
        expect(await tOB.singularityGauges(1, sglTokenMockAsset)).to.be.equal(tapOFTBalance.div(2));
        expect(await tOB.singularityGauges(1, sglTokenMock2Asset)).to.be.equal(tapOFTBalance.div(2));

        // Check TAP minting for 2 SGL assets with different weights
        await snapshot.restore();
        await tOLP.registerSingularity(sglTokenMock2.address, sglTokenMock2Asset, 2);
        await tOB.newEpoch();
        expect(await tOB.singularityGauges(1, sglTokenMockAsset)).to.be.equal(tapOFTBalance.div(3));
        expect(await tOB.singularityGauges(1, sglTokenMock2Asset)).to.be.equal(tapOFTBalance.mul(2).div(3));
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

        await setupEnv(tOB, tOLP, tapOFT, sglTokenMock, sglTokenMockAsset, sglTokenMock2, sglTokenMock2Asset);
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await tOB.newEpoch();

        await tOB.setPaymentToken(stableMock.address, stableMockOracle.address, '0x00');
        await tOB.setPaymentToken(ethMock.address, ethMockOracle.address, '0x00');
        const userLock1 = await lockAndParticipate(users[0], 3e8, 3600, tOLP, tOB, oTAP, yieldBox, sglTokenMock, sglTokenMockAsset);
        const userLock2 = await lockAndParticipate(users[1], 1e8, 3600, tOLP, tOB, oTAP, yieldBox, sglTokenMock, sglTokenMockAsset);

        const epoch = await tOB.epoch();

        const snapshot = await takeSnapshot();

        /// FULL ELIGIBLE STABLE

        // Exercise for full eligible TAP with 1e6 decimals stable, 50% discount
        {
            const eligibleTapAmount = userLock1.ybAmount
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e7).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div((await stableMockOracle.get('0x00'))._rate); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await tOB.connect(users[0]).getOTCDealDetails(userLock1.oTAPTokenID, stableMock.address, 0);
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }

        // Exercise for full eligible TAP with 1e6 decimals stable, 20.7083% discount
        {
            const eligibleTapAmount = userLock2.ybAmount
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e7).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div((await stableMockOracle.get('0x00'))._rate); // USDC price at 1
            const discount = rawPayment.mul(userLock2.oTAPOption.discount).div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await tOB.connect(users[1]).getOTCDealDetails(userLock2.oTAPTokenID, stableMock.address, 0);
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }

        await snapshot.restore();

        /// FULL ELIGIBLE WETH

        // Exercise for full eligible TAP with 1e18 decimals ETH, 50% discount
        {
            const eligibleTapAmount = userLock1.ybAmount
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e7).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div((await ethMockOracle.get('0x00'))._rate); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await tOB.connect(users[0]).getOTCDealDetails(userLock1.oTAPTokenID, ethMock.address, 0);
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }

        // Exercise for full eligible TAP with 1e18 decimals token, 20.7083% discount
        {
            const eligibleTapAmount = userLock2.ybAmount
                .mul(await tOB.singularityGauges(epoch, sglTokenMockAsset))
                .div(userLock1.ybAmount.add(userLock2.ybAmount));
            const otcDealAmountInUSD = BN(33e7).mul(eligibleTapAmount);
            const rawPayment = otcDealAmountInUSD.div((await ethMockOracle.get('0x00'))._rate); // USDC price at 1
            const discount = rawPayment.mul(userLock2.oTAPOption.discount).div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await tOB.connect(users[1]).getOTCDealDetails(userLock2.oTAPTokenID, ethMock.address, 0);
            expect(otcDetails.eligibleTapAmount).to.be.equal(eligibleTapAmount);
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }

        await snapshot.restore();

        /// 1 TAP STABLE

        // Exercise for 1 TAP with 1e6 decimals stable, 50% discount
        {
            const otcDealAmountInUSD = BN(33e7).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div((await stableMockOracle.get('0x00'))._rate); // USDC price at 1
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await tOB.connect(users[0]).getOTCDealDetails(userLock1.oTAPTokenID, stableMock.address, (1e18).toString());
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }

        // Exercise for 1 TAP with 1e6 decimals stable, 20.7083% discount
        {
            const otcDealAmountInUSD = BN(33e7).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div((await stableMockOracle.get('0x00'))._rate); // USDC price at 1
            const discount = rawPayment.mul(userLock2.oTAPOption.discount).div(1e6);
            const paymentTokenToSend = rawPayment.sub(discount).div(1e12);

            const otcDetails = await tOB.connect(users[1]).getOTCDealDetails(userLock2.oTAPTokenID, stableMock.address, (1e18).toString());
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }

        await snapshot.restore();

        /// 1 TAP ETH

        // Exercise for 1 TAP with 1e18 decimals token, 50% discount
        {
            const otcDealAmountInUSD = BN(33e7).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div((await ethMockOracle.get('0x00'))._rate); // ETH price at 1200
            const discount = rawPayment.mul(50).div(100);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await tOB.connect(users[0]).getOTCDealDetails(userLock1.oTAPTokenID, ethMock.address, (1e18).toString());
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }
        // Exercise for 1 TAP with 1e18 decimals token, 20.7083% discount
        {
            const otcDealAmountInUSD = BN(33e7).mul((1e18).toString());
            const rawPayment = otcDealAmountInUSD.div((await ethMockOracle.get('0x00'))._rate); // ETH price at 1200
            const discount = rawPayment.mul(userLock2.oTAPOption.discount).div(1e4 * 100);
            const paymentTokenToSend = rawPayment.sub(discount);

            const otcDetails = await tOB.connect(users[1]).getOTCDealDetails(userLock2.oTAPTokenID, ethMock.address, (1e18).toString());
            expect(otcDetails.paymentTokenAmount).to.be.equal(paymentTokenToSend);
        }
    });

    it('should exercise an option', async () => {
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

        await setupEnv(tOB, tOLP, tapOFT, sglTokenMock, sglTokenMockAsset, sglTokenMock2, sglTokenMock2Asset);
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await tOB.newEpoch();

        await tOB.setPaymentToken(stableMock.address, stableMockOracle.address, '0x00');
        await tOB.setPaymentToken(ethMock.address, ethMockOracle.address, '0x00');
        const userLock1 = await lockAndParticipate(users[0], 3e8, 3600, tOLP, tOB, oTAP, yieldBox, sglTokenMock, sglTokenMockAsset);
        const userLock2 = await lockAndParticipate(users[1], 1e8, 3600, tOLP, tOB, oTAP, yieldBox, sglTokenMock, sglTokenMockAsset);

        // Check requirements
        await expect(tOB.connect(users[1]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0)).to.be.rejectedWith(
            'TapiocaOptionBroker: Not approved or owner',
        );
        const snapshot = await takeSnapshot();
        await tOB.setPaymentToken(stableMock.address, hre.ethers.constants.AddressZero, '0x00');
        await expect(tOB.connect(users[0]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0)).to.be.rejectedWith(
            'TapiocaOptionBroker: Payment token not supported',
        );
        await snapshot.restore();
        await time.increase(userLock1.lockDuration);
        await expect(tOB.connect(users[0]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0)).to.be.rejectedWith(
            'TapiocaOptionBroker: Option expired',
        );
        await snapshot.restore();

        // Gauge emission check
        const epoch = await tOB.epoch();
        const sglGaugeTokenMock1 = (await tapOFT.balanceOf(tapOFT.address)).mul(2).div(3);
        const sglGaugeTokenMock2 = (await tapOFT.balanceOf(tapOFT.address)).mul(1).div(3);
        expect(await tOB.singularityGauges(epoch, sglTokenMockAsset)).to.equal(sglGaugeTokenMock1);
        expect(await tOB.singularityGauges(epoch, sglTokenMock2Asset)).to.equal(sglGaugeTokenMock2);

        // Exercise option for user 1 for full eligible TAP amount
        let user1EligibleTapAmount;
        let user1PaymentAmount;
        {
            const otcDetails = await tOB.connect(users[0]).getOTCDealDetails(userLock1.oTAPTokenID, stableMock.address, 0);
            const eligibleTapAmount = otcDetails.eligibleTapAmount;
            user1EligibleTapAmount = eligibleTapAmount;
            const paymentTokenToSend = otcDetails.paymentTokenAmount;
            user1PaymentAmount = paymentTokenToSend;

            // ERC20 checks
            await expect(tOB.connect(users[0]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0)).to.be.rejectedWith(
                'ERC20: balance too low',
            );
            await stableMock.mintTo(users[0].address, paymentTokenToSend);
            await expect(tOB.connect(users[0]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, 0)).to.be.rejectedWith(
                'ERC20: allowance too low',
            );
            await stableMock.connect(users[0]).approve(tOB.address, paymentTokenToSend);

            // Exercise option checks
            await expect(tOB.connect(users[0]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, eligibleTapAmount))
                .to.emit(tOB, 'ExerciseOption')
                .withArgs(epoch, users[0].address, stableMock.address, userLock1.oTAPTokenID, eligibleTapAmount); // Successful exercise

            expect(await tapOFT.balanceOf(users[0].address)).to.be.equal(eligibleTapAmount); // Check TAP transfer to user
            expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal((await tapOFT.mintedInWeek(epoch)).sub(eligibleTapAmount)); // Check TAP subtraction from TAP contract
            expect(await stableMock.balanceOf(tOB.address)).to.be.equal(paymentTokenToSend); // Check payment token transfer to TOB contract

            // end
            await expect(
                tOB.connect(users[0]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, eligibleTapAmount),
            ).to.be.rejectedWith('TapiocaOptionBroker: Already exercised');
        }

        // Exercise option for user 2 for half eligible TAP amount
        {
            const { eligibleTapAmount: __fullEligibleTapAMount } = await tOB
                .connect(users[1])
                .getOTCDealDetails(userLock2.oTAPTokenID, ethMock.address, 0);
            const eligibleTapAmount = __fullEligibleTapAMount.div(2);
            const { paymentTokenAmount: paymentTokenToSend } = await tOB
                .connect(users[1])
                .getOTCDealDetails(userLock2.oTAPTokenID, ethMock.address, eligibleTapAmount);

            await expect(
                tOB.connect(users[1]).exerciseOption(userLock2.oTAPTokenID, ethMock.address, eligibleTapAmount),
            ).to.be.rejectedWith('ERC20: balance too low');
            await ethMock.mintTo(users[1].address, paymentTokenToSend);

            await expect(
                tOB.connect(users[1]).exerciseOption(userLock2.oTAPTokenID, ethMock.address, eligibleTapAmount),
            ).to.be.rejectedWith('ERC20: allowance too low');
            await ethMock.connect(users[1]).approve(tOB.address, paymentTokenToSend);

            // Exercise option checks
            await expect(tOB.connect(users[1]).exerciseOption(userLock2.oTAPTokenID, ethMock.address, eligibleTapAmount))
                .to.emit(tOB, 'ExerciseOption')
                .withArgs(epoch, users[1].address, ethMock.address, userLock2.oTAPTokenID, eligibleTapAmount); // Successful exercise

            expect(await tapOFT.balanceOf(users[1].address)).to.be.equal(eligibleTapAmount); // Check TAP transfer to user
            expect(await tapOFT.balanceOf(tapOFT.address)).to.be.equal(
                (await tapOFT.mintedInWeek(epoch)).sub(eligibleTapAmount).sub(user1EligibleTapAmount),
            ); // Check TAP subtraction from TAP contract
            expect(await ethMock.balanceOf(tOB.address)).to.be.equal(paymentTokenToSend); // Check payment token transfer to TOB contract

            // end
            await expect(
                tOB.connect(users[1]).exerciseOption(userLock2.oTAPTokenID, ethMock.address, eligibleTapAmount),
            ).to.be.rejectedWith('TapiocaOptionBroker: Already exercised');
        }
    });

    it('should set payment beneficiary', async () => {
        const { users, tOB } = await loadFixture(setupFixture);

        await expect(tOB.connect(users[0]).setPaymentTokenBeneficiary(users[0].address)).to.be.revertedWith(
            'Ownable: caller is not the owner',
        );
        await tOB.setPaymentTokenBeneficiary(users[0].address);
        expect(await tOB.paymentTokenBeneficiary()).to.be.equal(users[0].address);
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

        await setupEnv(tOB, tOLP, tapOFT, sglTokenMock, sglTokenMockAsset, sglTokenMock2, sglTokenMock2Asset);
        await tOLP.setSGLPoolWEight(sglTokenMock.address, 2);
        await tOB.newEpoch();

        await tOB.setPaymentToken(stableMock.address, stableMockOracle.address, '0x00');
        const userLock1 = await lockAndParticipate(users[0], 3e8, 3600, tOLP, tOB, oTAP, yieldBox, sglTokenMock, sglTokenMockAsset);
        const otcDetails = await tOB.getOTCDealDetails(userLock1.oTAPTokenID, stableMock.address, 0);

        // Exercise
        await stableMock.mintTo(users[0].address, otcDetails.paymentTokenAmount);

        await stableMock.connect(users[0]).approve(tOB.address, otcDetails.paymentTokenAmount);
        await tOB.connect(users[0]).exerciseOption(userLock1.oTAPTokenID, stableMock.address, otcDetails.eligibleTapAmount);

        // Collect
        await expect(tOB.connect(users[0]).collectPaymentTokens([stableMock.address])).to.be.rejectedWith(
            'Ownable: caller is not the owner',
        );
        await tOB.collectPaymentTokens([stableMock.address]);
        expect(await stableMock.balanceOf(tOB.address)).to.be.equal(0);
        expect(await stableMock.balanceOf(paymentTokenBeneficiary.address)).to.be.equal(otcDetails.paymentTokenAmount);
    });
});
