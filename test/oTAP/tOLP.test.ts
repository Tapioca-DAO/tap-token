import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { setupFixture } from './fixtures';

describe.only('TapiocaOptionLiquidityProvision', () => {
    it('should check initial state', async () => {
        const { tOLP, signer } = await loadFixture(setupFixture);

        expect(await tOLP.owner()).to.be.eq(signer.address);
        expect(await tOLP.getSingularities()).to.be.deep.eq([]);
        expect(await tOLP.tokenCounter()).to.be.eq(0);
    });

    it('should register a singularity', async () => {
        const { users, tOLP, sglTokenMock, sglTokenMockAsset, sglTokenMock2, sglTokenMock2Asset } = await loadFixture(setupFixture);

        // Only owner can register a singularity
        await expect(tOLP.connect(users[0]).registerSingularity(sglTokenMock.address, sglTokenMockAsset)).to.be.revertedWith(
            'Ownable: caller is not the owner',
        );

        // Register a singularity
        await expect(tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset))
            .to.emit(tOLP, 'RegisterSingularity')
            .withArgs(sglTokenMock.address, sglTokenMockAsset);

        expect(await tOLP.getSingularities()).to.be.deep.eq([sglTokenMockAsset]);
        expect((await tOLP.activeSingularities(sglTokenMock.address)).sglAssetID).to.be.eq(sglTokenMockAsset);

        await expect(tOLP.registerSingularity(sglTokenMock2.address, sglTokenMock2Asset))
            .to.emit(tOLP, 'RegisterSingularity')
            .withArgs(sglTokenMock2.address, sglTokenMock2Asset);

        expect(await tOLP.getSingularities()).to.be.deep.eq([sglTokenMockAsset, sglTokenMock2Asset]);
        expect((await tOLP.activeSingularities(sglTokenMock2.address)).sglAssetID).to.be.eq(sglTokenMock2Asset);

        // Already registered
        await expect(tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset)).to.revertedWith(
            'TapiocaOptions: already registered',
        );
    });

    it('should unregister a singularity', async () => {
        const { users, tOLP, sglTokenMock, sglTokenMockAsset, sglTokenMock2, sglTokenMock2Asset } = await loadFixture(setupFixture);
        await tOLP.registerSingularity(sglTokenMock.address, sglTokenMockAsset);
        await tOLP.registerSingularity(sglTokenMock2.address, sglTokenMock2Asset);
        expect(await tOLP.getSingularities()).to.be.deep.eq([sglTokenMockAsset, sglTokenMock2Asset]);

        // Only owner can unregister a singularity
        await expect(tOLP.connect(users[0]).registerSingularity(sglTokenMock.address, sglTokenMockAsset)).to.be.revertedWith(
            'Ownable: caller is not the owner',
        );

        // Unregister a singularity
        await expect(tOLP.unregisterSingularity(sglTokenMock.address))
            .to.emit(tOLP, 'UnregisterSingularity')
            .withArgs(sglTokenMock.address, sglTokenMockAsset);

        expect(await tOLP.getSingularities()).to.be.deep.eq([sglTokenMock2Asset]);

        await expect(tOLP.unregisterSingularity(sglTokenMock2.address))
            .to.emit(tOLP, 'UnregisterSingularity')
            .withArgs(sglTokenMock2.address, sglTokenMock2Asset);

        expect((await tOLP.activeSingularities(sglTokenMock.address)).sglAssetID).to.be.eq(0);
        expect((await tOLP.activeSingularities(sglTokenMock2.address)).sglAssetID).to.be.eq(0);

        // Not registered
        await expect(tOLP.unregisterSingularity(sglTokenMock.address)).to.revertedWith('TapiocaOptions: not registered');
    });
});
