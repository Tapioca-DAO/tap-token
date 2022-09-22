import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { LZEndpointMock, EsTapOFT } from '../../typechain/';

import { deployLZEndpointMock, deployEsTap, BN } from '../test.utils';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('esTapOFT', () => {
    let signer: SignerWithAddress;
    let minter: SignerWithAddress;
    let burner: SignerWithAddress;

    let LZEndpointMock: LZEndpointMock;
    let esTap: EsTapOFT;

    async function register() {
        signer = (await ethers.getSigners())[0];
        minter = (await ethers.getSigners())[1];
        burner = (await ethers.getSigners())[2];

        LZEndpointMock = await deployLZEndpointMock(1);
        esTap = (await deployEsTap(LZEndpointMock.address, minter.address, burner.address)) as EsTapOFT;
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should check initial state', async () => {
        expect(await esTap.decimals()).eq(18);
        expect((await esTap.minter()).toLowerCase()).eq(minter.address.toLowerCase());
        expect((await esTap.burner()).toLowerCase()).eq(burner.address.toLowerCase());
    });

    it('should not create with invalid data', async () => {
        const factory = await ethers.getContractFactory('esTapOFT');
        await expect(factory.deploy(LZEndpointMock.address, minter.address, ethers.constants.AddressZero)).to.be.revertedWith(
            'Burner not valid',
        );
        await expect(factory.deploy(LZEndpointMock.address, ethers.constants.AddressZero, ethers.constants.AddressZero)).to.be.revertedWith(
            'Minter not valid',
        );
        await expect(
            factory.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero),
        ).to.be.revertedWith('LZ endpoint not valid');
    });

    it('should mint and burn', async () => {
        const amount = BN(1000).mul((1e18).toString());
        await expect(esTap.mintFor(signer.address, amount)).to.be.reverted;

        await esTap.connect(minter).mintFor(signer.address, amount);
        let signerEsTapBalance = await esTap.balanceOf(signer.address);
        expect(signerEsTapBalance.eq(amount)).to.be.true;

        await expect(esTap.burnFrom(signer.address, amount)).to.be.reverted;
        await esTap.connect(burner).burnFrom(signer.address, amount);
        signerEsTapBalance = await esTap.balanceOf(signer.address);
        expect(signerEsTapBalance.eq(0)).to.be.true;
    });

    it('should set minter and burner', async () => {
        await expect(esTap.connect(minter).setMinter(minter.address)).to.be.reverted;
        await expect(esTap.connect(minter).setBurner(minter.address)).to.be.reverted;

        await expect(esTap.connect(signer).setMinter(ethers.constants.AddressZero)).to.be.revertedWith('address not valid');
        await expect(esTap.connect(signer).setBurner(ethers.constants.AddressZero)).to.be.revertedWith('address not valid');
        await expect(esTap.connect(signer).setMinter(minter.address)).to.emit(esTap, 'MinterUpdated');
        await expect(esTap.connect(signer).setBurner(burner.address)).to.emit(esTap, 'BurnerUpdated');
    });
});
