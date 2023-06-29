import { PANIC_CODES } from '@nomicfoundation/hardhat-chai-matchers/panic';
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
    aml_computeMagnitude,
    aml_computeTarget,
} from '../test.utils';
import { setupTwTAPFixture } from './fixtures';
import ERC20MockArtifact from 'tapioca-sdk/dist/artifacts/tapioca-mocks/ERC20Mock.json';
import { ERC20Mock__factory } from 'tapioca-sdk/dist/typechain/tapioca-mocks';

const { formatUnits } = hre.ethers.utils;

const WEEK = 86400 * 7;
const EIGHT_DAYS = 86400 * 7;

const oneEth = BN(1e18);

describe('twTAP', () => {
    it('should participate', async () => {
        const { signer, users, twtap, tapOFT } = await loadFixture(
            setupTwTAPFixture,
        );

        // Setup - Get some Tap tokens
        const toMint = BN(2e18);
        const lockDuration = EIGHT_DAYS;
        await tapOFT.freeMint(toMint);

        // test tDP participation
        await expect(
            twtap.participate(signer.address, toMint, WEEK - 1),
        ).to.be.revertedWith('twTAP: Lock not a week');
        await expect(
            twtap.participate(signer.address, toMint, lockDuration),
        ).to.be.revertedWith('ERC20: insufficient allowance');

        const prevPoolState = await twtap.twAML();

        await tapOFT.approve(twtap.address, toMint);

        const lockTx = await twtap.participate(
            signer.address,
            toMint,
            lockDuration,
        );

        // Check balance
        expect(await tapOFT.balanceOf(twtap.address)).to.be.equal(toMint);

        // Check participation
        const twTAPTokenID = await twtap.mintedTWTap();

        const participation = await twtap.getParticipation(twTAPTokenID);

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
        expect(participation.averageMagnitude).to.equal(
            computedAML.averageMagnitude,
        );
        expect(participation.multiplier).to.equal(computedAML.multiplier);

        // Check AML state
        const newPoolState = await twtap.twAML();

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
        expect(twTAPTokenID).to.be.equal(1);

        expect(await twtap.ownerOf(twTAPTokenID)).to.be.equal(signer.address);
        expect(participation.expiry).to.be.equal(
            (await hre.ethers.provider.getBlock(lockTx.blockNumber!))
                .timestamp + lockDuration,
        );

        /// Check transfer of tOLP
        await tapOFT.approve(twtap.address, toMint);
        await expect(
            twtap.participate(signer.address, toMint, lockDuration),
        ).to.be.revertedWith('ERC20: transfer amount exceeds balance');

        // Check participation without enough voting power
        const user = users[0];
        const _amount = toMint.div(1000).sub(1); // < 0.1% of total weights

        await tapOFT.connect(user).freeMint(_amount);
        await tapOFT.connect(user).approve(twtap.address, _amount);
        await twtap
            .connect(user)
            .participate(user.address, _amount, lockDuration);

        expect(await twtap.twAML()).to.be.deep.equal(newPoolState); // No change in AML state
    });

    it('should exit position', async () => {
        const { signer, users, twtap, tapOFT } = await loadFixture(
            setupTwTAPFixture,
        );

        // Setup - Get some Tap tokens
        const toMint = BN(2e18);
        const lockDuration = EIGHT_DAYS;
        await tapOFT.freeMint(toMint);

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(
            twtap.exitPosition((await twtap.mintedTWTap()).add(1)),
        ).to.be.revertedWith('ERC721: invalid token ID');
        await snapshot.restore();

        // Participate
        await tapOFT.approve(twtap.address, toMint);
        await twtap.participate(signer.address, toMint, lockDuration);
        const twTAPTokenID = await twtap.mintedTWTap();
        const participation = await twtap.getParticipation(twTAPTokenID);
        const prevPoolState = await twtap.twAML();

        // Test exit
        await expect(twtap.exitPosition(twTAPTokenID)).to.be.revertedWith(
            'twTAP: Lock not expired',
        );
        expect(await tapOFT.balanceOf(twtap.address)).to.be.equal(toMint);

        await time.increase(lockDuration);
        await twtap.exitPosition(twTAPTokenID);

        // Check tokens transfer
        expect(await tapOFT.balanceOf(twtap.address)).to.be.equal(0);

        // Check AML update
        const newPoolState = await twtap.twAML();

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
        await tapOFT.connect(user).approve(twtap.address, _amount);
        await twtap
            .connect(user)
            .participate(user.address, _amount, lockDuration);

        await time.increase(lockDuration);

        const _twTAPTokenID = await twtap.mintedTWTap();
        await twtap.exitPosition(_twTAPTokenID);

        expect(await twtap.twAML()).to.be.deep.equal(newPoolState); // No change in AML state
        expect((await twtap.twAML()).cumulative).to.be.equal(0);
    });

    it('should enter and exit multiple positions', async () => {
        const { signer, twtap, tapOFT } = await loadFixture(setupTwTAPFixture);

        // Setup - Get some Tap tokens
        const toMint = BN(3e18);
        const toParticipate = BN(1e18);
        const lockDuration = EIGHT_DAYS;
        await tapOFT.freeMint(toMint);

        // Check exit before participation
        const snapshot = await takeSnapshot();
        await time.increase(lockDuration);
        await expect(
            twtap.exitPosition((await twtap.mintedTWTap()).add(1)),
        ).to.be.revertedWith('ERC721: invalid token ID');
        await snapshot.restore();

        // Participate
        await tapOFT.approve(twtap.address, toMint);
        await twtap.participate(signer.address, toParticipate, lockDuration);
        await twtap.participate(signer.address, toParticipate, lockDuration);
        await twtap.participate(signer.address, toParticipate, lockDuration);

        const twTAPTokenID = await twtap.mintedTWTap();

        await time.increase(lockDuration);

        {
            // Exit 1
            await twtap.exitPosition(twTAPTokenID);
        }

        {
            // Exit 2
            await twtap.exitPosition(twTAPTokenID.sub(1));
        }

        {
            // Exit 3
            await twtap.exitPosition(twTAPTokenID.sub(2));
        }
    });

    it('Should not distribute rewards if there are no lockers', async () => {
        const { twtap } = await loadFixture(setupTwTAPFixture);

        await time.increase(WEEK);
        await twtap.advanceWeek(1);

        await expect(
            twtap.distributeReward(0, oneEth.mul(2)),
        ).to.be.revertedWithPanic(PANIC_CODES.DIVISION_BY_ZERO);
    });

    it('Should not distribute rewards in week 0', async () => {
        // This is a special case of "no lockers": there can be none in week 0
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice, bob] = users;
        const [mock0] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), 2 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        await mock0.connect(bob).approve(twtap.address, oneEth.mul(2));

        expect(await twtap.currentWeek()).to.equal(0);
        expect(await twtap.lastProcessedWeek()).to.equal(0);

        const position = await twtap.getParticipation(aliceId);
        expect(position.lastInactive).to.equal(0);
        expect(position.lastActive).to.equal(2);

        await expect(
            twtap.connect(bob).distributeReward(0, oneEth.mul(2)),
        ).to.be.revertedWithPanic(PANIC_CODES.DIVISION_BY_ZERO);
    });

    it('Should distribute rewards after week 0', async () => {
        const { signer, twtap, tapOFT, users, tokens } = await loadFixture(
            setupTwTAPFixture,
        );
        const [alice, bob, carol] = users;
        const [mock0] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), 2 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        await twtap
            .connect(bob)
            .participate(bob.address, oneEth.mul(50), 5 * WEEK);
        const bobId = await twtap.mintedTWTap();

        await time.increase(WEEK);
        expect(await twtap.currentWeek()).to.equal(1);
        expect(await twtap.lastProcessedWeek()).to.equal(0);
        await twtap.advanceWeek(1);
        expect(await twtap.lastProcessedWeek()).to.equal(1);

        // Reward tokens 0, 1 and 2 correspond to the mock tokens:
        const distAmount = oneEth.mul(2);
        await mock0.connect(carol).approve(twtap.address, distAmount);
        await twtap.connect(carol).distributeReward(0, distAmount);

        const claimableAlice = await twtap.claimable(aliceId);
        const claimableBob = await twtap.claimable(bobId);

        const total = claimableAlice[0].add(claimableBob[0]);
        expect(total).to.be.lte(distAmount);
        expect(distAmount.sub(total)).to.be.lte(2);

        // Struct with 1 non-mapping member gets unwrapped to bigint;
        // `weekTotals` is the net number of votes:
        const posAlice = await twtap.getParticipation(aliceId);
        const posBob = await twtap.getParticipation(bobId);
        const weekTotals = await twtap.weekTotals(1);

        const votesAlice = posAlice.tapAmount.mul(posAlice.multiplier);
        const votesBob = posBob.tapAmount.mul(posBob.multiplier);
        expect(votesAlice.add(votesBob)).to.equal(weekTotals);
    });

    it('Should not distribute if totals are not up to date', async () => {
        const { signer, twtap, tapOFT, users, tokens } = await loadFixture(
            setupTwTAPFixture,
        );
        const [alice, bob] = users;
        const [mock0] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), 2 * WEEK);
        const aliceId = await twtap.mintedTWTap();

        await time.increase(WEEK);
        expect(await twtap.currentWeek()).to.equal(1);
        expect(await twtap.lastProcessedWeek()).to.equal(0);

        const distAmount = oneEth;
        await mock0.connect(bob).approve(twtap.address, distAmount);
        await expect(
            twtap.connect(bob).distributeReward(0, distAmount),
        ).to.be.revertedWith('twTAP: Advance week first');
    });

    it('Should tally up votes up to current week', async () => {
        const { signer, twtap, tapOFT, users, tokens } = await loadFixture(
            setupTwTAPFixture,
        );
        const [alice, bob, carol] = users;
        const [mock0] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), 5 * WEEK);
        const aliceId = await twtap.mintedTWTap();

        await twtap
            .connect(bob)
            .participate(bob.address, oneEth.mul(50), 2 * WEEK);
        const bobId = await twtap.mintedTWTap();

        const posAlice = await twtap.getParticipation(aliceId);
        const posBob = await twtap.getParticipation(bobId);

        expect(posAlice.lastInactive).to.equal(0);
        expect(posAlice.lastActive).to.equal(5);
        expect(posBob.lastInactive).to.equal(0);
        expect(posBob.lastActive).to.equal(2);

        const votesAlice = posAlice.tapAmount.mul(posAlice.multiplier);
        const votesBob = posBob.tapAmount.mul(posBob.multiplier);
        expect(votesAlice).to.be.gt(0);
        expect(votesBob).to.be.gt(0);
        expect(votesAlice).to.not.equal(votesBob);

        // WEEK 0
        // Before running the prefix sum in `advanceWeek()`:
        expect(await twtap.currentWeek()).to.equal(0);
        expect(await twtap.lastProcessedWeek()).to.equal(0);

        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(1)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(2)).to.equal(0);
        expect(await twtap.weekTotals(3)).to.equal(votesBob.mul(-1));
        expect(await twtap.weekTotals(4)).to.equal(0);
        expect(await twtap.weekTotals(5)).to.equal(0);
        expect(await twtap.weekTotals(6)).to.equal(votesAlice.mul(-1));
        expect(await twtap.weekTotals(7)).to.equal(0);
        expect(await twtap.weekTotals(8)).to.equal(0);
        expect(await twtap.weekTotals(9)).to.equal(0);

        // WEEK 2
        await time.increase(2 * WEEK);
        expect(await twtap.currentWeek()).to.equal(2);
        expect(await twtap.lastProcessedWeek()).to.equal(0);
        await twtap.advanceWeek(10);
        expect(await twtap.currentWeek()).to.equal(2);
        expect(await twtap.lastProcessedWeek()).to.equal(2); // Not 10

        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(1)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(2)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(3)).to.equal(votesBob.mul(-1));
        expect(await twtap.weekTotals(4)).to.equal(0);
        expect(await twtap.weekTotals(5)).to.equal(0);
        expect(await twtap.weekTotals(6)).to.equal(votesAlice.mul(-1));
        expect(await twtap.weekTotals(7)).to.equal(0);
        expect(await twtap.weekTotals(8)).to.equal(0);
        expect(await twtap.weekTotals(9)).to.equal(0);

        // WEEK 4, but only current up to week 3:
        await time.increase(2 * WEEK);
        expect(await twtap.currentWeek()).to.equal(4);
        expect(await twtap.lastProcessedWeek()).to.equal(2);
        await twtap.advanceWeek(1);
        expect(await twtap.lastProcessedWeek()).to.equal(3);

        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(1)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(2)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(3)).to.equal(votesAlice);
        expect(await twtap.weekTotals(4)).to.equal(0);
        expect(await twtap.weekTotals(5)).to.equal(0);
        expect(await twtap.weekTotals(6)).to.equal(votesAlice.mul(-1));
        expect(await twtap.weekTotals(7)).to.equal(0);
        expect(await twtap.weekTotals(8)).to.equal(0);
        expect(await twtap.weekTotals(9)).to.equal(0);

        // WEEK 4, current:
        await twtap.advanceWeek(1);
        expect(await twtap.lastProcessedWeek()).to.equal(4);

        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(1)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(2)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(3)).to.equal(votesAlice);
        expect(await twtap.weekTotals(4)).to.equal(votesAlice);
        expect(await twtap.weekTotals(5)).to.equal(0);
        expect(await twtap.weekTotals(6)).to.equal(votesAlice.mul(-1));
        expect(await twtap.weekTotals(7)).to.equal(0);
        expect(await twtap.weekTotals(8)).to.equal(0);
        expect(await twtap.weekTotals(9)).to.equal(0);

        // WEEK 8, current:
        await time.increase(4 * WEEK);
        await twtap.advanceWeek(100);
        expect(await twtap.lastProcessedWeek()).to.equal(8);
        expect(await twtap.currentWeek()).to.equal(8);

        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(1)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(2)).to.equal(votesAlice.add(votesBob));
        expect(await twtap.weekTotals(3)).to.equal(votesAlice);
        expect(await twtap.weekTotals(4)).to.equal(votesAlice);
        expect(await twtap.weekTotals(5)).to.equal(votesAlice);
        expect(await twtap.weekTotals(6)).to.equal(0);
        expect(await twtap.weekTotals(7)).to.equal(0);
        expect(await twtap.weekTotals(8)).to.equal(0);
        expect(await twtap.weekTotals(9)).to.equal(0);
    });

    it('Should allow only the owner to add reward tokens', async () => {
        const { signer, twtap, users, tokens } = await loadFixture(
            setupTwTAPFixture,
        );
        const [alice] = users;

        const mock = await (
            (await ethers.getContractFactoryFromArtifact(
                ERC20MockArtifact,
            )) as ERC20Mock__factory
        ).deploy('New Token', 'NEW', oneEth, 18, signer.address);

        await expect(
            twtap.connect(alice).addRewardToken(mock.address),
        ).to.be.revertedWith('Ownable: caller is not the owner');
        expect(await twtap.rewardTokens(tokens.length - 1)).to.equal(
            tokens[tokens.length - 1].address,
        );
        // TODO: Test that rewardTokens(tokens.length) is OOB?

        await twtap.addRewardToken(mock.address);
        expect(await twtap.rewardTokens(tokens.length)).to.equal(mock.address);
    });

    it('Should allow claiming rewards immediately', async () => {
        const { signer, twtap, tapOFT, users, tokens } = await loadFixture(
            setupTwTAPFixture,
        );
        const [alice, bob, carol] = users;
        const [mock0, mock1] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), 3 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        await twtap
            .connect(bob)
            .participate(bob.address, oneEth.mul(50), 2 * WEEK);
        const bobId = await twtap.mintedTWTap();

        const getBalances = async () => ({
            alice0: await mock0.balanceOf(alice.address),
            alice1: await mock1.balanceOf(alice.address),
            bob0: await mock0.balanceOf(bob.address),
            bob1: await mock1.balanceOf(bob.address),
        });

        const balancesBefore = await getBalances();

        const posAlice = await twtap.getParticipation(aliceId);
        const posBob = await twtap.getParticipation(bobId);

        expect(posAlice.lastInactive).to.equal(0);
        expect(posAlice.lastActive).to.equal(3);
        expect(posBob.lastInactive).to.equal(0);
        expect(posBob.lastActive).to.equal(2);

        const votesAlice = posAlice.tapAmount.mul(posAlice.multiplier);
        const votesBob = posBob.tapAmount.mul(posBob.multiplier);

        // WEEK 2 still
        await time.increase(2.5 * WEEK);
        await twtap.advanceWeek(10);
        expect(await twtap.currentWeek()).to.equal(2);
        expect(await twtap.lastProcessedWeek()).to.equal(2); // Not 10
        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(2)).to.equal(votesAlice.add(votesBob));

        const distAmount0 = oneEth.mul(5);
        await mock0.connect(carol).approve(twtap.address, distAmount0);
        await twtap.connect(carol).distributeReward(0, distAmount0.div(2));
        await twtap.connect(carol).distributeReward(0, distAmount0.div(2));

        const distAmount1 = oneEth.mul(3);
        await mock1.connect(carol).approve(twtap.address, distAmount1);
        await twtap.connect(carol).distributeReward(1, distAmount1);

        // Alice and Bob can both claim the reward immediately:
        await twtap.connect(alice).claimRewards(aliceId, alice.address);
        await twtap.connect(bob).claimRewards(bobId, bob.address);

        // Nothing claimable remains:
        for (const tokenId of [aliceId, bobId]) {
            const rest = await twtap.claimable(tokenId);
            for (const rewardAmount of rest) {
                expect(rewardAmount).to.equal(0);
            }
        }

        // Alice and Bob got the reward:
        const balancesAfter = await getBalances();
        const aliceReward0 = balancesAfter.alice0.sub(balancesBefore.alice0);
        const aliceReward1 = balancesAfter.alice1.sub(balancesBefore.alice1);
        const bobReward0 = balancesAfter.bob0.sub(balancesBefore.bob0);
        const bobReward1 = balancesAfter.bob1.sub(balancesBefore.bob1);

        // Rewards add up, more or less (due to rounding):
        const total0 = aliceReward0.add(bobReward0);
        const total1 = aliceReward1.add(bobReward1);
        expect(distAmount0).to.be.gte(total0);
        expect(distAmount1).to.be.gte(total1);
        expect(distAmount0.sub(total0)).to.be.lte(2);
        expect(distAmount1.sub(total1)).to.be.lte(2);

        // Rewards are proportional to votes. With some rounding tolerance
        // R_a / votes_a = R_b / votes_b => R_a * votes_b = R_b * votes_A
        const lhs0 = aliceReward0.mul(votesBob);
        const lhs1 = aliceReward1.mul(votesBob);
        const rhs0 = bobReward0.mul(votesAlice);
        const rhs1 = bobReward1.mul(votesAlice);
        const d0 = lhs0.sub(rhs0).abs();
        const d1 = lhs1.sub(rhs1).abs();

        // Equal up to at most a billionth of the total:
        expect(d0.mul(1_000_000_000)).to.be.lte(lhs0);
        expect(d1.mul(1_000_000_000)).to.be.lte(lhs1);

        // Claimed amounts are stored in the contract:
        expect(await twtap.claimed(aliceId, 0)).to.equal(aliceReward0);
        expect(await twtap.claimed(aliceId, 1)).to.equal(aliceReward1);
        expect(await twtap.claimed(bobId, 0)).to.equal(bobReward0);
        expect(await twtap.claimed(bobId, 1)).to.equal(bobReward1);
    });

    it('Should allow claiming rewards after expiration', async () => {
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice, bob, carol] = users;
        const [mock0, mock1, mock2] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        await twtap
            .connect(bob)
            .participate(bob.address, oneEth.mul(50), 2 * WEEK);
        const bobId = await twtap.mintedTWTap();

        const getBalances = async () => ({
            alice0: await mock0.balanceOf(alice.address),
            alice1: await mock1.balanceOf(alice.address),
            alice2: await mock2.balanceOf(alice.address),
            bob0: await mock0.balanceOf(bob.address),
            bob1: await mock1.balanceOf(bob.address),
            bob2: await mock2.balanceOf(bob.address),
        });

        const balancesBefore = await getBalances();

        // WEEK 2
        await time.increase(2 * WEEK);
        await twtap.advanceWeek(2);
        expect(await twtap.currentWeek()).to.equal(2);
        expect(await twtap.lastProcessedWeek()).to.equal(2);

        const distAmount0_w2 = oneEth.mul(5);
        await mock0.connect(carol).approve(twtap.address, distAmount0_w2);
        await twtap.connect(carol).distributeReward(0, distAmount0_w2);

        const distAmount1_w2 = oneEth.mul(3);
        await mock1.connect(carol).approve(twtap.address, distAmount1_w2);
        await twtap.connect(carol).distributeReward(1, distAmount1_w2);

        // WEEK 3. Only Alice is eligible for this reward:
        await time.increase(WEEK);
        await twtap.advanceWeek(1);
        expect(await twtap.currentWeek()).to.equal(3);
        expect(await twtap.lastProcessedWeek()).to.equal(3);

        const distAmount2_w3 = oneEth;
        await mock2.connect(carol).approve(twtap.address, distAmount2_w3);
        await twtap.connect(carol).distributeReward(2, distAmount2_w3);

        // WEEK 100. Alice and Bob claim only now:
        await time.increase(97 * WEEK);
        await twtap.advanceWeek(97);
        expect(await twtap.currentWeek()).to.equal(100);
        expect(await twtap.lastProcessedWeek()).to.equal(100);
        await twtap.connect(alice).claimRewards(aliceId, alice.address);
        await twtap.connect(bob).claimRewards(bobId, bob.address);

        // Alice and Bob got the reward:
        const balancesAfter = await getBalances();
        const aliceReward0 = balancesAfter.alice0.sub(balancesBefore.alice0);
        const aliceReward1 = balancesAfter.alice1.sub(balancesBefore.alice1);
        const aliceReward2 = balancesAfter.alice2.sub(balancesBefore.alice2);
        const bobReward0 = balancesAfter.bob0.sub(balancesBefore.bob0);
        const bobReward1 = balancesAfter.bob1.sub(balancesBefore.bob1);
        const bobReward2 = balancesAfter.bob2.sub(balancesBefore.bob2);

        // Bob did not get a share in second reward:
        expect(bobReward0).to.be.gt(0);
        expect(bobReward1).to.be.gt(0);
        expect(bobReward2).to.equal(0);

        // Alice got the entire second reward, up to rounding errors because
        expect(aliceReward0).to.be.gt(0);
        expect(aliceReward1).to.be.gt(0);
        expect(aliceReward2).to.be.lte(distAmount2_w3);
        expect(distAmount2_w3.sub(aliceReward2)).to.be.lte(5);
    });

    it('Should allow claiming rewards after exiting position', async () => {
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice, bob] = users;
        const [mock0] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(10), 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        const aliceBefore = await mock0.balanceOf(alice.address);

        // WEEK 2
        await time.increase(2 * WEEK);
        await twtap.advanceWeek(2);
        expect(await twtap.currentWeek()).to.equal(2);
        expect(await twtap.lastProcessedWeek()).to.equal(2);

        const distAmount = oneEth.mul(2);
        await mock0.connect(bob).approve(twtap.address, distAmount);
        await twtap.connect(bob).distributeReward(0, distAmount);

        // Alice claims this reward immediately:
        await twtap.connect(alice).claimRewards(aliceId, alice.address);
        const aliceMiddle = await mock0.balanceOf(alice.address);
        expect(aliceMiddle).to.be.gt(aliceBefore);

        // WEEK 4. Alice's position expires:
        // If THIS fails, run the test again in case the extra second pushed it
        // over the edge
        await time.increase(2 * WEEK + 1);
        await twtap.advanceWeek(2);
        expect(await twtap.currentWeek()).to.equal(4); // <-- THIS
        expect(await twtap.lastProcessedWeek()).to.equal(4);

        await twtap.exitPosition(aliceId);
        // TODO: Is the TAP release already tested somewhere?

        // Alice is nevertheless eligible for the reward; the period ran from
        // week 1 to week 4, and week 4 is not over yet:
        const distAmount2 = oneEth;
        await mock0.connect(bob).approve(twtap.address, distAmount2);
        await twtap.connect(bob).distributeReward(0, distAmount2);

        await twtap.connect(alice).claimRewards(aliceId, alice.address);
        const aliceAfter = await mock0.balanceOf(alice.address);
        expect(aliceAfter).to.be.gt(aliceMiddle);

        const aliceFirstReward = aliceMiddle.sub(aliceBefore);
        const aliceSecondReward = aliceAfter.sub(aliceMiddle);
        const aliceReward = aliceAfter.sub(aliceBefore);

        expect(aliceFirstReward).to.be.lte(distAmount);
        expect(distAmount.sub(aliceFirstReward)).to.be.lte(5);

        expect(aliceSecondReward).to.be.lte(distAmount2);
        expect(distAmount2.sub(aliceSecondReward)).to.be.lte(5);

        // WEEK 5.
        // Alice is no longer eligible for the reward, and since there are no
        // more stakers, rewards cannot be paid.
        await time.increase(WEEK);
        await twtap.advanceWeek(1);
        await expect(
            twtap.connect(bob).distributeReward(0, oneEth.mul(2)),
        ).to.be.revertedWithPanic(PANIC_CODES.DIVISION_BY_ZERO);
    });

    it('Should allow claiming rewards for someone else', async () => {
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice, bob, carol] = users;
        const [mock0] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(10), 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        const aliceBefore = await mock0.balanceOf(alice.address);

        // WEEK 2
        await time.increase(2 * WEEK);
        await twtap.advanceWeek(2);
        expect(await twtap.currentWeek()).to.equal(2);
        expect(await twtap.lastProcessedWeek()).to.equal(2);

        const distAmount = oneEth.div(3);
        await mock0.connect(bob).approve(twtap.address, distAmount);
        await twtap.connect(bob).distributeReward(0, distAmount);

        // Carol can claim the reward for Alice, but only to Alice's address:
        await expect(
            twtap.connect(carol).claimRewards(aliceId, bob.address),
        ).to.be.revertedWith('twTAP: cannot claim');
        await expect(
            twtap.connect(carol).claimRewards(aliceId, carol.address),
        ).to.be.revertedWith('twTAP: cannot claim');
        await twtap.connect(carol).claimRewards(aliceId, alice.address);

        const aliceAfter = await mock0.balanceOf(alice.address);
        const aliceReward = aliceAfter.sub(aliceBefore);
        expect(aliceReward).to.be.lte(distAmount);
        expect(distAmount.sub(aliceReward)).to.be.lte(5);
    });

    it('Should allow claiming rewards of someone who approved', async () => {
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice, bob, carol] = users;
        const [mock0] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(10), 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        await twtap
            .connect(bob)
            .participate(bob.address, oneEth.mul(10), 4 * WEEK);
        const bobId = await twtap.mintedTWTap();
        const carolBefore = await mock0.balanceOf(carol.address);

        // WEEK 2
        await time.increase(2 * WEEK);
        await twtap.advanceWeek(2);
        expect(await twtap.currentWeek()).to.equal(2);
        expect(await twtap.lastProcessedWeek()).to.equal(2);

        const distAmount = oneEth.mul(3).div(8);
        await mock0.connect(bob).approve(twtap.address, distAmount);
        await twtap.connect(bob).distributeReward(0, distAmount);

        // Carol can claim Alice's reward for herself if Alice approved Carol:
        await expect(
            twtap.connect(carol).claimRewards(aliceId, bob.address),
        ).to.be.revertedWith('twTAP: cannot claim');
        await twtap.connect(alice).approve(carol.address, aliceId);
        await twtap.connect(carol).claimRewards(aliceId, carol.address);

        // Carol can claim Bob's reward if Bob approved Carol for all tokens:
        await expect(
            twtap.connect(carol).claimRewards(bobId, carol.address),
        ).to.be.revertedWith('twTAP: cannot claim');
        await twtap.connect(bob).setApprovalForAll(carol.address, 1);
        await twtap.connect(carol).claimRewards(bobId, carol.address);

        const carolAfter = await mock0.balanceOf(carol.address);
        const carolReward = carolAfter.sub(carolBefore);
        expect(carolReward).to.be.lte(distAmount);
        expect(distAmount.sub(carolReward)).to.be.lte(5);
    });

    // EDGE CASES / COVERAGE. Below are mostly to get to 100%:

    it('Should show 0 claimable for empty positions', async () => {
        const { twtap, tokens } = await loadFixture(setupTwTAPFixture);
        expect(await twtap.mintedTWTap()).to.equal(0);
        const claimable = await twtap.claimable(0);
        expect(claimable.length).to.equal(tokens.length);
        expect(claimable.length).to.be.gt(0);
        for (const c of claimable) {
            expect(c).to.equal(0);
        }
    });

    it('Should allow participation in the "future":', async () => {
        // Rewards cannot be given out either, but it's a possible state:
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice] = users;
        const [mock0] = tokens;

        // WEEK 3
        await time.increase(3 * WEEK);
        expect(await twtap.currentWeek()).to.equal(3);
        expect(await twtap.lastProcessedWeek()).to.equal(0);
        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(10), 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        const posAlice = await twtap.getParticipation(aliceId);
        expect(posAlice.lastInactive).to.equal(3);
        expect(posAlice.lastActive).to.equal(7);
        const votesAlice = posAlice.tapAmount.mul(posAlice.multiplier);

        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(1)).to.equal(0);
        expect(await twtap.weekTotals(2)).to.equal(0);
        expect(await twtap.weekTotals(3)).to.equal(0);
        expect(await twtap.weekTotals(4)).to.equal(votesAlice);
        expect(await twtap.weekTotals(5)).to.equal(0);
        expect(await twtap.weekTotals(6)).to.equal(0);
        expect(await twtap.weekTotals(7)).to.equal(0);
        expect(await twtap.weekTotals(8)).to.equal(votesAlice.mul(-1));
        expect(await twtap.weekTotals(9)).to.equal(0);

        // Nothing claimable yet:
        const claimable = await twtap.claimable(aliceId);
        expect(claimable.length).to.equal(tokens.length);
        expect(claimable.length).to.be.gt(0);
        for (const c of claimable) {
            expect(c).to.equal(0);
        }

        await time.increase(10 * WEEK);
        await twtap.advanceWeek(20);

        expect(await twtap.currentWeek()).to.equal(13);
        expect(await twtap.lastProcessedWeek()).to.equal(13);

        expect(await twtap.weekTotals(0)).to.equal(0);
        expect(await twtap.weekTotals(1)).to.equal(0);
        expect(await twtap.weekTotals(2)).to.equal(0);
        expect(await twtap.weekTotals(3)).to.equal(0);
        expect(await twtap.weekTotals(4)).to.equal(votesAlice);
        expect(await twtap.weekTotals(5)).to.equal(votesAlice);
        expect(await twtap.weekTotals(6)).to.equal(votesAlice);
        expect(await twtap.weekTotals(7)).to.equal(votesAlice);
        expect(await twtap.weekTotals(8)).to.equal(0);
        expect(await twtap.weekTotals(9)).to.equal(0);
    });

    it('Should show no votes in the view right after expiry', async () => {
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice] = users;
        const [mock0] = tokens;

        // WEEK 3
        await time.increase(3 * WEEK);
        expect(await twtap.currentWeek()).to.equal(3);
        expect(await twtap.lastProcessedWeek()).to.equal(0);
        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(10), 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();

        // Right before expiry:
        await time.increase(4 * WEEK - 1);
        const posAlice0 = await twtap.getParticipation(aliceId);
        expect(posAlice0.multiplier).to.equal(1_000_000); // Only participant..

        // Right after:
        await time.increase(2);
        const posAlice1 = await twtap.getParticipation(aliceId);
        expect(posAlice1.multiplier).to.equal(0); // Only participant..
    });

    it('Should allow exiting a position to another recipient', async () => {
        const { twtap, users, tapOFT } = await loadFixture(setupTwTAPFixture);
        const [alice, bob] = users;

        const tapAmount = oneEth.mul(9).div(5);
        const bobBefore = await tapOFT.balanceOf(bob.address);

        // WEEK 3
        await time.increase(3 * WEEK);
        expect(await twtap.currentWeek()).to.equal(3);
        expect(await twtap.lastProcessedWeek()).to.equal(0);
        await twtap
            .connect(alice)
            .participate(alice.address, tapAmount, 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();

        await time.increase(5 * WEEK);

        // Bob cannot take Alice's TAP (without permission. TODO: Test?)
        await expect(
            twtap.connect(bob).releaseTap(aliceId, bob.address),
        ).to.be.revertedWith('twTAP: cannot claim');

        // Alice can send TAP to Bob:
        await twtap.connect(alice).releaseTap(aliceId, bob.address);
        const bobAfter = await tapOFT.balanceOf(bob.address);

        expect(tapAmount).to.be.gt(0);
        expect(bobAfter.sub(bobBefore)).to.equal(tapAmount);
    });

    it('Should do nothing if exiting a position twice', async () => {
        const { twtap, users, tapOFT } = await loadFixture(setupTwTAPFixture);
        const [alice, bob] = users;

        const tapAmount = oneEth.mul(9).div(5);

        // WEEK 3
        await time.increase(3 * WEEK);
        expect(await twtap.currentWeek()).to.equal(3);
        expect(await twtap.lastProcessedWeek()).to.equal(0);
        await twtap
            .connect(alice)
            .participate(alice.address, tapAmount, 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        const aliceAfterStake = await tapOFT.balanceOf(alice.address);

        await time.increase(5 * WEEK);

        // Bob can exit Alice's position (releasing the funds to Alice)
        await twtap.connect(bob).exitPosition(aliceId);
        const aliceAfterRelease = await tapOFT.balanceOf(alice.address);

        expect(tapAmount).to.be.gt(0);
        expect(aliceAfterRelease.sub(aliceAfterStake)).to.equal(tapAmount);

        // Bob can exit Alice's position again; nothing will happen
        await twtap.connect(bob).exitPosition(aliceId);
        expect(await tapOFT.balanceOf(alice.address)).to.equal(
            aliceAfterRelease,
        );
    });

    it('Should not update cumulative on exiting small positions', async () => {
        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice, bob, carol] = users;
        const [mock0, mock1, mock2] = tokens;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), 4 * WEEK);
        const aliceId = await twtap.mintedTWTap();
        await twtap
            .connect(bob)
            .participate(bob.address, oneEth.div(100), 2 * WEEK);
        const bobId = await twtap.mintedTWTap();

        const posBob = await twtap.getParticipation(bobId);
        expect(posBob.hasVotingPower).to.equal(false);

        const cumulativeBefore = (await twtap.twAML()).cumulative;

        await time.increase(3 * WEEK);
        await twtap.exitPosition(bobId);

        const cumulativeAfter = (await twtap.twAML()).cumulative;
        expect(cumulativeBefore).to.equal(cumulativeAfter);
    });

    it('Should not allow an expiry time that overflows', async () => {
        const YEAR = 86400n * 365n;
        const BILLION = 1_000_000_000n;
        const ok = 2n * BILLION * YEAR;
        const tooMuch = 3n * BILLION * YEAR;

        const { twtap, users, tokens } = await loadFixture(setupTwTAPFixture);
        const [alice, bob] = users;

        await twtap
            .connect(alice)
            .participate(alice.address, oneEth.mul(100), ok);
        const aliceId = await twtap.mintedTWTap();

        await expect(
            twtap
                .connect(alice)
                .participate(alice.address, oneEth.mul(100), tooMuch),
        ).to.be.revertedWith('twTAP: too long');
    });
});
