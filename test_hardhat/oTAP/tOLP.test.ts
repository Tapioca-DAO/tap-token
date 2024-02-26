import {
    loadFixture,
    takeSnapshot,
} from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre from 'hardhat';
import { BN, getERC721PermitSignature, time_travel } from '../test.utils';
import { setupFixture } from './fixtures';

describe('TapiocaOptionLiquidityProvision', () => {
    it('should check initial state', async () => {
        const { tOLP, signer } = await loadFixture(setupFixture);

        expect(await tOLP.owner()).to.be.eq(signer.address);
        expect(await tOLP.getSingularities()).to.be.deep.eq([]);
        expect(await tOLP.tokenCounter()).to.be.eq(0);
    });

    it('should register a singularity', async () => {
        const {
            users,
            tOLP,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);

        // Only owner can register a singularity
        await expect(
            tOLP
                .connect(users[0])
                .registerSingularity(
                    sglTokenMock.address,
                    sglTokenMockAsset,
                    0,
                ),
        ).to.be.reverted;

        // Register a singularity
        await expect(
            tOLP.registerSingularity(
                sglTokenMock.address,
                sglTokenMockAsset,
                0,
            ),
        )
            .to.emit(tOLP, 'RegisterSingularity')
            .withArgs(sglTokenMock.address, sglTokenMockAsset)
            .and.to.emit(tOLP, 'UpdateTotalSingularityPoolWeights')
            .withArgs(1);

        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(1);
        expect(
            (await tOLP.activeSingularities(sglTokenMock.address)).sglAssetID,
        ).to.be.eq(sglTokenMockAsset);
        expect(await tOLP.sglAssetIDToAddress(sglTokenMockAsset)).to.be.equal(
            sglTokenMock.address,
        );
        expect(await tOLP.getSingularities()).to.be.deep.eq([
            sglTokenMockAsset,
        ]);

        await expect(
            tOLP.registerSingularity(
                sglTokenMock2.address,
                sglTokenMock2Asset,
                0,
            ),
        )
            .to.emit(tOLP, 'RegisterSingularity')
            .withArgs(sglTokenMock2.address, sglTokenMock2Asset)
            .and.to.emit(tOLP, 'UpdateTotalSingularityPoolWeights')
            .withArgs(2);

        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(2);
        expect(
            (await tOLP.activeSingularities(sglTokenMock2.address)).sglAssetID,
        ).to.be.eq(sglTokenMock2Asset);
        expect(await tOLP.sglAssetIDToAddress(sglTokenMock2Asset)).to.be.equal(
            sglTokenMock2.address,
        );
        expect(await tOLP.getSingularities()).to.be.deep.eq([
            sglTokenMockAsset,
            sglTokenMock2Asset,
        ]);

        // Already registered
        await expect(
            tOLP.registerSingularity(
                sglTokenMock.address,
                sglTokenMockAsset,
                0,
            ),
        ).to.reverted;
        await expect(
            tOLP.registerSingularity(
                sglTokenMock.address,
                32323, // random asset ID
                0,
            ),
        ).to.reverted;
        await expect(
            tOLP.registerSingularity(
                sglTokenMock2.address,
                sglTokenMock2Asset,
                0,
            ),
        ).to.reverted;
        await expect(
            tOLP.registerSingularity(
                sglTokenMock2.address,
                213123, // random asset ID
                0,
            ),
        ).to.reverted;
    });

    it('should unregister a singularity', async () => {
        const {
            users,
            tOLP,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);
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
        expect(await tOLP.getSingularities()).to.be.deep.eq([
            sglTokenMockAsset,
            sglTokenMock2Asset,
        ]);

        // Only owner can unregister a singularity
        await expect(
            tOLP
                .connect(users[0])
                .registerSingularity(
                    sglTokenMock.address,
                    sglTokenMockAsset,
                    0,
                ),
        ).to.be.reverted;

        // Unregister a singularity
        await expect(tOLP.unregisterSingularity(sglTokenMock.address))
            .to.emit(tOLP, 'UnregisterSingularity')
            .withArgs(sglTokenMock.address, sglTokenMockAsset)
            .and.to.emit(tOLP, 'UpdateTotalSingularityPoolWeights')
            .withArgs(1);

        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(1);
        expect(
            (await tOLP.activeSingularities(sglTokenMock.address)).sglAssetID,
        ).to.be.eq(0);
        expect(await tOLP.sglAssetIDToAddress(sglTokenMockAsset)).to.be.equal(
            hre.ethers.constants.AddressZero,
        );
        expect(await tOLP.getSingularities()).to.be.deep.eq([
            sglTokenMock2Asset,
        ]);

        await expect(tOLP.unregisterSingularity(sglTokenMock2.address))
            .to.emit(tOLP, 'UnregisterSingularity')
            .withArgs(sglTokenMock2.address, sglTokenMock2Asset)
            .and.to.emit(tOLP, 'UpdateTotalSingularityPoolWeights')
            .withArgs(0);

        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(0);
        expect(
            (await tOLP.activeSingularities(sglTokenMock2.address)).sglAssetID,
        ).to.be.eq(0);
        expect(await tOLP.sglAssetIDToAddress(sglTokenMock2Asset)).to.be.equal(
            hre.ethers.constants.AddressZero,
        );
        expect(await tOLP.getSingularities()).to.be.deep.eq([]);

        // Not registered
        await expect(tOLP.unregisterSingularity(sglTokenMock.address)).to
            .reverted;
        await expect(tOLP.unregisterSingularity(sglTokenMock2.address)).to
            .reverted;
    });

    it('should create a lock', async () => {
        const {
            signer,
            tOLP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
        } = await loadFixture(setupFixture);

        // Setup
        const lockDuration = await tOLP.EPOCH_DURATION();
        const lockAmount = 1e8;
        await tOLP.registerSingularity(
            sglTokenMock.address,
            sglTokenMockAsset,
            0,
        );
        await sglTokenMock.freeMint(lockAmount);
        await sglTokenMock.approve(yieldBox.address, lockAmount);
        await yieldBox.depositAsset(
            sglTokenMockAsset,
            signer.address,
            signer.address,
            lockAmount,
            0,
        );
        await yieldBox.setApprovalForAll(tOLP.address, true);

        const lockShares = await yieldBox.toShare(
            sglTokenMockAsset,
            lockAmount,
            false,
        );

        // Requirements
        await expect(
            tOLP.lock(signer.address, sglTokenMock.address, 0, lockShares),
        ).to.revertedWithCustomError(tOLP, 'DurationTooShort');
        await expect(
            tOLP.lock(signer.address, sglTokenMock.address, lockDuration, 0),
        ).to.reverted;
        await expect(
            tOLP.lock(
                signer.address,
                sglTokenMock2.address,
                lockDuration,
                lockShares,
            ),
        ).to.reverted;

        // Lock
        await expect(
            tOLP.lock(
                signer.address,
                sglTokenMock.address,
                lockDuration,
                lockShares,
            ),
        )
            .to.emit(tOLP, 'Mint')
            .withArgs(signer.address, sglTokenMockAsset, []);
        const tokenID = await tOLP.tokenCounter();

        expect(await tOLP.tokenCounter()).to.be.eq(1);
        expect(await tOLP.ownerOf(1)).to.be.eq(signer.address);

        // Validate YieldBox transfers
        expect(
            await yieldBox.balanceOf(tOLP.address, sglTokenMockAsset),
        ).to.be.eq(lockShares);

        // Validate position
        const lockPosition = await tOLP.lockPositions(tokenID);
        expect(lockPosition.ybShares).to.be.eq(lockShares);
        expect(lockPosition.lockDuration).to.be.eq(lockDuration);
        expect(lockPosition.lockTime).to.be.eq(
            (await hre.ethers.provider.getBlock('latest')).timestamp,
        );
        expect(
            (await tOLP.activeSingularities(sglTokenMock.address))
                .totalDeposited,
        ).to.be.eq(lockShares);
    });

    it('Should unlock a lock', async () => {
        const {
            signer,
            users,
            tOLP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
        } = await loadFixture(setupFixture);

        // Setup
        const lockDuration = await tOLP.EPOCH_DURATION();
        const lockAmount = 1e8;
        await tOLP.registerSingularity(
            sglTokenMock.address,
            sglTokenMockAsset,
            0,
        );
        await sglTokenMock.freeMint(lockAmount);
        await sglTokenMock.approve(yieldBox.address, lockAmount);
        await yieldBox.depositAsset(
            sglTokenMockAsset,
            signer.address,
            signer.address,
            lockAmount,
            0,
        );
        const lockShares = await yieldBox.toShare(
            sglTokenMockAsset,
            lockAmount,
            false,
        );

        await yieldBox.setApprovalForAll(tOLP.address, true);
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            lockShares,
        );
        const tokenID = await tOLP.tokenCounter();

        // Requirements
        await expect(tOLP.unlock(tokenID, sglTokenMock.address, signer.address))
            .to.be.reverted;
        await time_travel(lockDuration.toNumber());
        await expect(
            tOLP.unlock(tokenID, sglTokenMock2.address, signer.address),
        ).to.be.reverted;
        await expect(
            tOLP
                .connect(users[0])
                .unlock(tokenID, sglTokenMock.address, users[0].address),
        ).to.be.reverted;

        // Unlock
        await expect(tOLP.unlock(tokenID, sglTokenMock.address, signer.address))
            .to.emit(tOLP, 'Burn')
            .withArgs(signer.address, sglTokenMockAsset, []);

        // Check balances
        expect(
            await yieldBox.balanceOf(signer.address, sglTokenMockAsset),
        ).to.be.eq(lockShares);
        expect(
            (await tOLP.activeSingularities(sglTokenMock.address))
                .totalDeposited,
        ).to.be.eq(0);

        // Can not unlock more than once the same lock
        await expect(tOLP.unlock(tokenID, sglTokenMock.address, signer.address))
            .to.be.reverted;
    });

    it('Should should set an SGL pool weight', async () => {
        const {
            users,
            tOLP,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);

        // Setup
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
        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(2);

        await expect(
            tOLP.connect(users[0]).setSGLPoolWeight(sglTokenMock.address, 1),
        ).to.be.reverted;

        await expect(tOLP.setSGLPoolWeight(sglTokenMock.address, 4))
            .to.emit(tOLP, 'SetSGLPoolWeight')
            .withArgs(sglTokenMock.address, 4);

        expect(
            (await tOLP.activeSingularities(sglTokenMock.address)).poolWeight,
        ).to.be.eq(4);
        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(5);
    });

    it('Should be able to use permit', async () => {
        const {
            signer,
            users,
            tOLP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
        } = await loadFixture(setupFixture);

        // Setup
        const lockDuration = await tOLP.EPOCH_DURATION();
        const lockAmount = 1e8;
        await tOLP.registerSingularity(
            sglTokenMock.address,
            sglTokenMockAsset,
            0,
        );
        await sglTokenMock.freeMint(lockAmount);
        await sglTokenMock.approve(yieldBox.address, lockAmount);
        await yieldBox.depositAsset(
            sglTokenMockAsset,
            signer.address,
            signer.address,
            lockAmount,
            0,
        );
        await yieldBox.setApprovalForAll(tOLP.address, true);
        await tOLP.lock(
            signer.address,
            sglTokenMock.address,
            lockDuration,
            1e8,
        );
        const tokenID = await tOLP.tokenCounter();

        const [normalUser, otherAddress] = users;

        const deadline =
            (await hre.ethers.provider.getBlock('latest')).timestamp + 10_000;
        const { v, r, s } = await getERC721PermitSignature(
            signer,
            tOLP,
            normalUser.address,
            tokenID,
            BN(deadline),
        );

        // Check if it works
        const snapshot = await takeSnapshot();
        await expect(
            tOLP.permit(normalUser.address, tokenID, deadline, v, r, s),
        )
            .to.emit(tOLP, 'Approval')
            .withArgs(signer.address, normalUser.address, tokenID);

        // Check that it can't be used twice
        await expect(
            tOLP.permit(normalUser.address, tokenID, deadline, v, r, s),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used after deadline
        await time_travel(10_001);
        await expect(
            tOLP.permit(normalUser.address, tokenID, deadline, v, r, s),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used with wrong signature
        const {
            v: v2,
            r: r2,
            s: s2,
        } = await getERC721PermitSignature(
            signer,
            tOLP,
            otherAddress.address,
            tokenID,
            BN(deadline),
        );
        await expect(
            tOLP.permit(normalUser.address, tokenID, deadline, v2, r2, s2),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can be batch called
        const permit = tOLP.interface.encodeFunctionData('permit', [
            normalUser.address,
            tokenID,
            deadline,
            v,
            r,
            s,
        ]);
        const transfer = tOLP.interface.encodeFunctionData('transferFrom', [
            signer.address,
            normalUser.address,
            tokenID,
        ]);

        await expect(tOLP.connect(normalUser).batch([permit, transfer], true))
            .to.emit(tOLP, 'Transfer')
            .withArgs(signer.address, normalUser.address, tokenID);
    });

    it('Should handle market rescue correctly', async () => {
        const {
            signer,
            users,
            tOLP,
            yieldBox,
            sglTokenMock,
            sglTokenMockAsset,
            sglTokenMock2,
            sglTokenMock2Asset,
        } = await loadFixture(setupFixture);

        // Setup
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
        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(2);

        await expect(
            tOLP.connect(users[0]).activateSGLPoolRescue(sglTokenMock.address),
        ).to.be.reverted;

        await expect(tOLP.activateSGLPoolRescue(sglTokenMock.address))
            .to.emit(tOLP, 'ActivateSGLPoolRescue')
            .withArgs(sglTokenMock.address);
        expect((await tOLP.activeSingularities(sglTokenMock.address)).rescue).to
            .be.true;

        await expect(tOLP.activateSGLPoolRescue(sglTokenMock.address)).to.be
            .reverted;

        expect(await tOLP.totalSingularityPoolWeights()).to.be.eq(1);

        // Setup sglTokenMock deposit
        {
            const lockDuration = await tOLP.EPOCH_DURATION();
            const lockAmount = 1e8;

            await sglTokenMock.freeMint(lockAmount);
            await sglTokenMock.approve(yieldBox.address, lockAmount);
            await yieldBox.depositAsset(
                sglTokenMockAsset,
                signer.address,
                signer.address,
                lockAmount,
                0,
            );
            const lockShares = await yieldBox.toShare(
                sglTokenMockAsset,
                lockAmount,
                false,
            );

            await yieldBox.setApprovalForAll(tOLP.address, true);
            await expect(
                tOLP.lock(
                    signer.address,
                    sglTokenMock.address,
                    lockDuration,
                    lockShares,
                ),
            ).to.be.reverted;
        }

        // Setup sglTokenMock2 deposit + rescue withdrawal
        {
            const lockDuration = await tOLP.EPOCH_DURATION();
            const lockAmount = 1e8;

            await sglTokenMock2.freeMint(lockAmount);
            await sglTokenMock2.approve(yieldBox.address, lockAmount);
            await yieldBox.depositAsset(
                sglTokenMock2Asset,
                signer.address,
                signer.address,
                lockAmount,
                0,
            );
            const lockShares = await yieldBox.toShare(
                sglTokenMock2Asset,
                lockAmount,
                false,
            );

            await yieldBox.setApprovalForAll(tOLP.address, true);
            await tOLP.lock(
                signer.address,
                sglTokenMock2.address,
                lockDuration,
                lockShares,
            );
            const tokenID = await tOLP.tokenCounter();

            await tOLP.activateSGLPoolRescue(sglTokenMock2.address);

            await expect(
                tOLP.unlock(tokenID, sglTokenMock2.address, signer.address),
            ).to.emit(tOLP, 'Burn');

            expect(
                await yieldBox.balanceOf(signer.address, sglTokenMock2Asset),
            ).to.be.equal(lockShares);
        }
    });
});
