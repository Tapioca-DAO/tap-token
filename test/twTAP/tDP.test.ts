import {
  loadFixture,
  takeSnapshot,
  time,
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { TapiocaDAOPortal } from "../../typechain";
import {
  BN,
  aml_computeAverageMagnitude,
  aml_computeMagnitude,
  aml_computeTarget,
} from "../test.utils";
import { setupTDPFixture } from "./fixtures";

const WEEK = 86400 * 7;
const EIGHT_DAYS = 86400 * 7;

describe("TapiocaDAOPortal", () => {
  it("should participate", async () => {
    const { signer, users, tDP, tapOFT } = await loadFixture(
      setupTDPFixture
    );

    // Setup - Get some Tap tokens
    const toMint = BN(2e18);
    const lockDuration = EIGHT_DAYS;
    await tapOFT.freeMint(toMint);

    // test tDP participation
    await expect(
      tDP.participate(signer.address, toMint, WEEK-1)
    ).to.be.revertedWith("TapiocaDAOPortal: Lock not a week");
    await expect(
      tDP.participate(signer.address, toMint, lockDuration)
    ).to.be.revertedWith("ERC20: insufficient allowance");

    const prevPoolState = await tDP.twAML();

    await tapOFT.approve(tDP.address, toMint);
    const lockTx = await tDP.participate(signer.address, toMint, lockDuration);

    // Check balance
    expect(await tapOFT.balanceOf(tDP.address)).to.be.equal(toMint);

    // Check participation
    const twTAPTokenID = await tDP.mintedTWTap();

    const participation = await tDP.participants(twTAPTokenID);

    const computedAML = {
      magnitude: BN(0),
      averageMagnitude: BN(0),
      multiplier: BN(0),
    };
    computedAML.magnitude = aml_computeMagnitude(BN(lockDuration), BN(0));
    computedAML.averageMagnitude = aml_computeAverageMagnitude(
      computedAML.magnitude,
      BN(0),
      prevPoolState.totalParticipants.add(1)
    );
    const multiplier = aml_computeTarget(
      computedAML.magnitude,
      BN(0),
      BN(10e4),
      BN(100e4)
    );
    computedAML.votes = multiplier.mul(toMint);

    expect(participation.hasVotingPower).to.be.true;
    expect(participation.averageMagnitude).to.be.equal(
      computedAML.averageMagnitude
    );

    // Check AML state
    const newPoolState = await tDP.twAML();

    expect(newPoolState.totalParticipants).to.be.equal(
      prevPoolState.totalParticipants.add(1)
    );
    expect(newPoolState.totalDeposited).to.be.equal(
      prevPoolState.totalDeposited.add(toMint)
    );
    expect(newPoolState.cumulative).to.be.equal(computedAML.magnitude);
    expect(newPoolState.averageMagnitude).to.be.equal(
      computedAML.averageMagnitude
    );

    // Check twTAP minting
    expect(twTAPTokenID).to.be.equal(1);

    expect(await tDP.ownerOf(twTAPTokenID)).to.be.equal(signer.address);
    expect(participation.votes).to.be.equal(computedAML.votes);
    expect(participation.expiry).to.be.equal(
      (await hre.ethers.provider.getBlock(lockTx.blockNumber!)).timestamp +
        lockDuration
    );

    /// Check transfer of tOLP
    await tapOFT.approve(tDP.address, toMint);
    await expect(
      tDP.participate(signer.address, toMint, lockDuration)
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");

    // Check participation without enough voting power
    const user = users[0];
    const _amount = toMint.div(1000).sub(1); // < 0.1% of total weights

    await tapOFT.connect(user).freeMint(_amount);
    await tapOFT.connect(user).approve(tDP.address, _amount);
    await tDP.connect(user).participate(user.address, _amount, lockDuration);

    expect(await tDP.twAML()).to.be.deep.equal(newPoolState); // No change in AML state
  });

  it('should exit position', async () => {
      const { signer, users, tDP, tapOFT } = await loadFixture(
          setupTDPFixture,
      );

      // Setup - Get some Tap tokens
      const toMint = BN(2e18);
      const lockDuration = EIGHT_DAYS;
      await tapOFT.freeMint(toMint);

      // Check exit before participation
      const snapshot = await takeSnapshot();
      await time.increase(lockDuration);
      await expect(
          tDP.exitPosition((await tDP.mintedTWTap()).add(1)),
      ).to.be.revertedWith('ERC721: invalid token ID');
      await snapshot.restore();

      // Participate
      await tapOFT.approve(tDP.address, toMint);
      await tDP.participate(signer.address, toMint, lockDuration);
      const twTAPTokenID = await tDP.mintedTWTap();
      const participation = await tDP.participants(twTAPTokenID);
      const prevPoolState = await tDP.twAML();

      // Test exit
      await expect(tDP.exitPosition(twTAPTokenID)).to.be.revertedWith(
          'TapiocaDAOPortal: Lock not expired',
      );
      expect(await tapOFT.balanceOf(tDP.address)).to.be.equal(toMint);

      await time.increase(lockDuration);
      await tDP.exitPosition(twTAPTokenID);

      // Check tokens transfer
      expect(await tapOFT.balanceOf(tDP.address)).to.be.equal(0);

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

      const _twTAPTokenID = await tDP.mintedTWTap();
      await tDP.exitPosition(_twTAPTokenID);

      expect(await tDP.twAML()).to.be.deep.equal(newPoolState); // No change in AML state
      expect((await tDP.twAML()).cumulative).to.be.equal(0);
  });

  it('should enter and exit multiple positions', async () => {
      const { signer, tDP, tapOFT } = await loadFixture(
          setupTDPFixture,
      );

      // Setup - Get some Tap tokens
      const toMint = BN(3e18);
      const toParticipate = BN(1e18);
      const lockDuration = EIGHT_DAYS;
      await tapOFT.freeMint(toMint);

      // Check exit before participation
      const snapshot = await takeSnapshot();
      await time.increase(lockDuration);
      await expect(
          tDP.exitPosition((await tDP.mintedTWTap()).add(1)),
      ).to.be.revertedWith('ERC721: invalid token ID');
      await snapshot.restore();

      // Participate
      await tapOFT.approve(tDP.address, toMint);
      await tDP.participate(signer.address, toParticipate, lockDuration);
      await tDP.participate(signer.address, toParticipate, lockDuration);
      await tDP.participate(signer.address, toParticipate, lockDuration);

      const twTAPTokenID = await tDP.mintedTWTap();

      await time.increase(lockDuration);

      {
          // Exit 1
          await tDP.exitPosition(twTAPTokenID);
      }

      {
          // Exit 2
          await tDP.exitPosition(twTAPTokenID.sub(1));
      }

      {
          // Exit 3
          await tDP.exitPosition(twTAPTokenID.sub(2));
      }
  });
});
