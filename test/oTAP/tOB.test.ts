import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { setupFixture } from './fixtures';
import hre from 'hardhat';
import { aml_computeAverageMagnitude, aml_computeDiscount, aml_computeMagnitude, BN, time_travel } from '../test.utils';

describe.only('TapiocaOptionBroker', () => {
    it('should claim oTAP and TAP', async () => {
        const { tOB, oTAP, tapOFT } = await loadFixture(setupFixture);

        await tOB.oTAPBrokerClaim();
        expect(await oTAP.broker()).to.be.eq(tOB.address);

        await tapOFT.setMinter(tOB.address);
        expect(await tapOFT.minter()).to.be.eq(tOB.address);
    });

    it('should participate', async () => {
        const { signer, users, tOLP, tOB, tapOFT, oTAP, sglTokenMock, sglTokenMockAsset, sglTokenMock2, sglTokenMock2Asset, yieldBox } =
            await loadFixture(setupFixture);

        // Setup tOB
        await tOB.oTAPBrokerClaim();
        await tapOFT.setMinter(tOB.address);

        // Setup - register a singularity, mint and deposit in YB, lock in tOLP
        const amount = 1e8;
        const lockDuration = 10;
        await tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset);

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

        await tOB.participate(tokenID);
        const participation = await tOB.participants(signer.address, sglTokenMockAsset);

        // Check participation
        const computedAML = {
            magnitude: BN(0),
            averageMagnitude: BN(0),
            discount: BN(0),
        };
        computedAML.magnitude = aml_computeMagnitude(BN(lockDuration), BN(0));
        computedAML.averageMagnitude = aml_computeAverageMagnitude(computedAML.magnitude, BN(0), prevPoolState.totalParticipants.add(1));
        computedAML.discount = aml_computeDiscount(computedAML.magnitude, BN(0), BN(5e4), BN(50e4));

        expect(participation.hasParticipated).to.be.true;
        expect(participation.hasVotingPower).to.be.true;
        expect(participation.magnitude).to.be.equal(computedAML.magnitude);

        // Check AML state
        const newPoolState = await tOB.twAML(sglTokenMockAsset);
        expect(newPoolState.totalParticipants).to.be.equal(prevPoolState.totalParticipants.add(1));
        expect(newPoolState.totalWeight).to.be.equal(prevPoolState.totalWeight.add(amount));

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

        await expect(tOB.participate(tokenID)).to.be.revertedWith('TapiocaOptionBroker: Already participating');
    });
});
