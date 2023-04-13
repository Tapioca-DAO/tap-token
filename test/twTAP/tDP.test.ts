import {
    loadFixture,
    takeSnapshot,
    time,
} from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre from 'hardhat';
import { TapiocaDAOPortal } from '../../typechain';
import {
    BN,
    aml_computeAverageMagnitude,
    aml_computeMagnitude,
    aml_computeTarget,
} from '../test.utils';
import { setupTDPFixture } from './fixtures';

describe('TapiocaOptionPortal', () => {
    const setupEnv = async (tDP: TapiocaDAOPortal) => {
        await tDP.twTAPPortalClaim();
    };

    it('should claim twTAP', async () => {
        const { tDP, twTAP } = await loadFixture(setupTDPFixture);

        await tDP.twTAPPortalClaim();
        expect(await twTAP.portal()).to.be.eq(tDP.address);
    });

    it('should participate', async () => {
        const { signer, users, tDP, tapOFT, twTAP } = await loadFixture(
            setupTDPFixture,
        );

        // Setup tDP
        await setupEnv(tDP);

        // Setup - Get some Tap tokens
        const toMint = BN(2e18);
        const lockDuration = 1000; // 1000 seconds
        await tapOFT.freeMint(toMint);

        // test tDP participation
        await expect(
            tDP.participate(signer.address, toMint, lockDuration),
        ).to.be.revertedWith('ERC20: insufficient allowance');

        const prevPoolState = await tDP.twAML();

        await tapOFT.approve(tDP.address, toMint);
        const lockTx = await tDP.participate(
            signer.address,
            toMint,
            lockDuration,
        );

        // Check balance
        expect(await tapOFT.balanceOf(tDP.address)).to.be.equal(toMint);

        // Check participation
        const participation = await tDP.participants(signer.address);
        const computedAML = {
            magnitude: BN(0),
            averageMagnitude: BN(0),
            multiplier: BN(0),
        };
        computedAML.magnitude = aml_computeMagnitude(BN(lockDuration), BN(0));
        computedAML.averageMagnitude = aml_computeAverageMagnitude(
            computedAML.magnitude,
            BN(0),
            prevPoolState.totalParticipants.add(1),
        );
        computedAML.multiplier = aml_computeTarget(
            computedAML.magnitude,
            BN(0),
            BN(10e4),
            BN(100e4),
        );

        expect(participation.hasVotingPower).to.be.true;
        expect(participation.averageMagnitude).to.be.equal(
            computedAML.averageMagnitude,
        );

        // Check AML state
        const newPoolState = await tDP.twAML();

        expect(newPoolState.totalParticipants).to.be.equal(
            prevPoolState.totalParticipants.add(1),
        );
        expect(newPoolState.totalDeposited).to.be.equal(
            prevPoolState.totalDeposited.add(toMint),
        );
        expect(newPoolState.cumulative).to.be.equal(computedAML.magnitude);
        expect(newPoolState.averageMagnitude).to.be.equal(
            computedAML.averageMagnitude,
        );

        // Check twTAP minting
        const twpTAPTokenID = await twTAP.mintedTWTap();

        expect(twpTAPTokenID).to.be.equal(1);
        expect(await twTAP.ownerOf(twpTAPTokenID)).to.be.equal(signer.address);

        const [, twpTAPToken] = await twTAP.attributes(twpTAPTokenID);

        expect(twpTAPToken.multiplier).to.be.equal(computedAML.multiplier);
        expect(twpTAPToken.expiry).to.be.equal(
            (await hre.ethers.provider.getBlock(lockTx.blockNumber!))
                .timestamp + lockDuration,
        );

        /// Check transfer of tOLP
        await tapOFT.approve(tDP.address, toMint);
        await expect(
            tDP.participate(signer.address, toMint, lockDuration),
        ).to.be.revertedWith('ERC20: transfer amount exceeds balance');

        // Check participation without enough voting power
        const user = users[0];
        const _amount = toMint.div(1000).sub(1); // < 0.1% of total weights

        await tapOFT.connect(user).freeMint(_amount);
        await tapOFT.connect(user).approve(tDP.address, _amount);
        await tDP
            .connect(user)
            .participate(user.address, _amount, lockDuration);

        expect(await tDP.twAML()).to.be.deep.equal(newPoolState); // No change in AML state
    });

    it('should exit position', async () => {
        const { signer, users, tDP, tapOFT, twTAP } = await loadFixture(
            setupTDPFixture,
        );

        // Setup tDP
        await setupEnv(tDP);

        // Setup - Get some Tap tokens
        const toMint = BN(2e18);
        const lockDuration = 1000; // 1000 seconds
        await tapOFT.freeMint(toMint);

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(
            tDP.exitPosition((await twTAP.mintedTWTap()).add(1)),
        ).to.be.revertedWith('TapiocaDAOPortal: twTAP position does not exist');
        await snapshot.restore();

        // Participate
        await tapOFT.approve(tDP.address, toMint);
        await tDP.participate(signer.address, toMint, lockDuration);
        const twTAPTokenID = await twTAP.mintedTWTap();
        const participation = await tDP.participants(signer.address);
        const prevPoolState = await tDP.twAML();

        // Test exit
        await expect(tDP.exitPosition(twTAPTokenID)).to.be.revertedWith(
            'TapiocaDAOPortal: Lock not expired',
        );
        expect(await tapOFT.balanceOf(tDP.address)).to.be.equal(toMint);

        await time.increase(lockDuration);
        await expect(tDP.exitPosition(twTAPTokenID)).to.be.revertedWith(
            'twTap: only approved or owner',
        );

        await twTAP.approve(tDP.address, twTAPTokenID);
        await tDP.exitPosition(twTAPTokenID);

        // Check tokens transfer
        expect(await tapOFT.balanceOf(tDP.address)).to.be.equal(0);
        expect(await twTAP.exists(twTAPTokenID)).to.be.false;

        // Check AML update
        const newPoolState = await tDP.twAML();

        expect(newPoolState.totalParticipants).to.be.equal(
            prevPoolState.totalParticipants.sub(1),
        );
        expect(newPoolState.totalDeposited).to.be.equal(
            prevPoolState.totalDeposited.sub(toMint),
        );
        expect(newPoolState.cumulative).to.be.equal(
            prevPoolState.cumulative.sub(participation.averageMagnitude),
        );

        // Do not remove participation if not participating
        await snapshot.restore();

        const user = users[0];
        const _amount = toMint.div(1000).sub(1); // < 0.1% of total weights

        await tapOFT.connect(user).freeMint(_amount);
        await tapOFT.connect(user).approve(tDP.address, _amount);
        await tDP
            .connect(user)
            .participate(user.address, _amount, lockDuration);

        await time.increase(lockDuration);

        const _twTAPTokenID = await twTAP.mintedTWTap();
        await twTAP.connect(user).approve(tDP.address, _twTAPTokenID);
        await tDP.connect(user).exitPosition(_twTAPTokenID);

        expect(await tDP.twAML()).to.be.deep.equal(newPoolState); // No change in AML state
        expect((await tDP.twAML()).cumulative).to.be.equal(0);
    });

    it('should enter and exit multiple positions', async () => {
        const { signer, tDP, tapOFT, twTAP } = await loadFixture(
            setupTDPFixture,
        );

        // Setup tOB
        await setupEnv(tDP);

        // Setup - Get some Tap tokens
        const toMint = BN(3e18);
        const toParticipate = BN(1e18);
        const lockDuration = 1000; // 1000 seconds
        await tapOFT.freeMint(toMint);

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(
            tDP.exitPosition((await twTAP.mintedTWTap()).add(1)),
        ).to.be.revertedWith('TapiocaDAOPortal: twTAP position does not exist');
        await snapshot.restore();

        // Participate
        await tapOFT.approve(tDP.address, toMint);
        await tDP.participate(signer.address, toParticipate, lockDuration);
        await tDP.participate(signer.address, toParticipate, lockDuration);
        await tDP.participate(signer.address, toParticipate, lockDuration);

        const twTAPTokenID = await twTAP.mintedTWTap();

        await time.increase(lockDuration);

        {
            // Exit 1
            await twTAP.approve(tDP.address, twTAPTokenID);
            await tDP.exitPosition(twTAPTokenID);
        }

        {
            // Exit 2
            await twTAP.approve(tDP.address, twTAPTokenID.sub(1));
            await tDP.exitPosition(twTAPTokenID.sub(1));
        }

        {
            // Exit 3
            await twTAP.approve(tDP.address, twTAPTokenID.sub(2));
            await tDP.exitPosition(twTAPTokenID.sub(2));
        }
    });
});
