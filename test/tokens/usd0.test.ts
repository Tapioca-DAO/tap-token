import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import writeJsonFile from 'write-json-file';
import { TapOFT, USD0, LZEndpointMock } from '../../typechain/';
import { VeTap } from '../../typechain/contracts/vyper/VeTap.vy';

import { deployLZEndpointMock, deployUsd0, BN } from '../test.utils';
import { BigNumberish } from 'ethers';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('tapOFT', () => {
    let signer: SignerWithAddress;
    let minter: SignerWithAddress;
    let normalUser: SignerWithAddress;
    let lzEndpointMock: LZEndpointMock;
    let usd0: USD0;

    async function register() {
        signer = (await ethers.getSigners())[0];
        minter = (await ethers.getSigners())[1];
        normalUser = (await ethers.getSigners())[2];
        lzEndpointMock = (await deployLZEndpointMock(1)) as LZEndpointMock;
        usd0 = (await deployUsd0(lzEndpointMock.address)) as USD0;
    }
    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should test initial values', async () => {
        const signerIsAllowedToMint = await usd0.allowedMinter(signer.address);
        const signerIsAllowedToBurn = await usd0.allowedBurner(signer.address);
        expect(signerIsAllowedToMint).to.be.true;
        expect(signerIsAllowedToBurn).to.be.true;

        const decimals = await usd0.decimals();
        expect(decimals == 18).to.be.true;
    });

    it('should set minters and burners', async () => {
        let minterStatus = await usd0.allowedMinter(minter.address);
        expect(minterStatus).to.be.false;

        await usd0.setMinterStatus(minter.address, true);
        minterStatus = await usd0.allowedMinter(minter.address);
        expect(minterStatus).to.be.true;

        let burnerStatus = await usd0.allowedBurner(minter.address);
        expect(burnerStatus).to.be.false;

        await usd0.setBurnerStatus(minter.address, true);
        burnerStatus = await usd0.allowedBurner(minter.address);
        expect(burnerStatus).to.be.true;
    });

    it('should mint and burn', async () => {
        const amount = BN(1000).mul((1e18).toString());

        let usd0Balance = await usd0.balanceOf(normalUser.address);
        expect(usd0Balance.eq(0)).to.be.true;

        await expect(usd0.connect(normalUser).mint(normalUser.address, amount)).to.be.revertedWith('unauthorized');
        await usd0.connect(signer).mint(normalUser.address, amount);

        usd0Balance = await usd0.balanceOf(normalUser.address);
        expect(usd0Balance.eq(amount)).to.be.true;

        await expect(usd0.connect(normalUser).burn(normalUser.address, amount)).to.be.revertedWith('unauthorized');
        await usd0.connect(signer).burn(normalUser.address, amount);
        usd0Balance = await usd0.balanceOf(normalUser.address);
        expect(usd0Balance.eq(0)).to.be.true;
    });
});
