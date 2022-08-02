import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { LZEndpointMock, TapOFT } from '../../typechain';

import { deployLZEndpointMock, deployTapiocaOFT, BN } from '../test.utils';

describe('tapOFT', () => {
    let signer: SignerWithAddress;
    let minter: SignerWithAddress;
    let normalUser: SignerWithAddress;

    let LZEndpointMock0: LZEndpointMock;
    let LZEndpointMock1: LZEndpointMock;

    let tapiocaOFT0: TapOFT;
    let tapiocaOFT1: TapOFT;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        minter = (await ethers.getSigners())[1];
        normalUser = (await ethers.getSigners())[2];

        LZEndpointMock0 = await deployLZEndpointMock(0);
        LZEndpointMock1 = await deployLZEndpointMock(1);

        tapiocaOFT0 = (await deployTapiocaOFT(LZEndpointMock0.address, signer.address)) as TapOFT;
        tapiocaOFT1 = (await deployTapiocaOFT(LZEndpointMock1.address, signer.address)) as TapOFT;
    });

    it('should check initial state', async () => {
        expect(await tapiocaOFT0.decimals()).eq(18);
        expect(await tapiocaOFT1.decimals()).eq(18);

        expect(await LZEndpointMock0.getChainId()).eq(0);
        expect(await LZEndpointMock1.getChainId()).eq(1);

        expect(await tapiocaOFT0.paused()).to.be.false;
        expect(await tapiocaOFT1.paused()).to.be.false;

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        const totalSupply = BN(100000000).mul((1e18).toString());
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not be able to deploy with an empty LayerZero endpoint', async () => {
        const factory = await ethers.getContractFactory('TapOFT');
        await expect(
            factory.deploy(
                ethers.constants.AddressZero,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
                signer.address,
            ),
        ).to.be.reverted;
    });

    it('should set minter', async () => {
        const currentMinter = await tapiocaOFT0.minter();
        expect(currentMinter).to.eq(ethers.constants.AddressZero);
        await expect(tapiocaOFT0.connect(minter).setMinter(minter.address)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setMinter(ethers.constants.AddressZero)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');
    });

    it('should mint more', async () => {
        const amount = BN(100000000).mul((1e18).toString());
        const finalAmount = BN(300000000).mul((1e18).toString());

        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(normalUser).createTAP(signer.address, amount)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');
        await expect(tapiocaOFT0.connect(minter).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        expect(signerBalance).to.eq(finalAmount);

        const totalSupply = await tapiocaOFT0.totalSupply();
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not mint when paused', async () => {
        const amount = BN(100000000).mul((1e18).toString());
        await tapiocaOFT0.pauseSendTokens(true);
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.be.reverted;
        await tapiocaOFT0.pauseSendTokens(false);
        await expect(tapiocaOFT0.connect(signer).createTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Minted');
    });

    it('should burn', async () => {
        const amount = BN(20000000).mul((1e18).toString());
        const finalAmount = BN(60000000).mul((1e18).toString());

        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(normalUser).removeTAP(signer.address, amount)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).removeTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Burned');
        await expect(tapiocaOFT0.connect(minter).removeTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Burned');

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        expect(signerBalance).to.eq(finalAmount);

        const totalSupply = await tapiocaOFT0.totalSupply();
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not burn when paused', async () => {
        const amount = BN(100000000).mul((1e18).toString());
        await tapiocaOFT0.pauseSendTokens(true);
        await expect(tapiocaOFT0.connect(signer).removeTAP(signer.address, amount)).to.be.reverted;
        await tapiocaOFT0.pauseSendTokens(false);
        await expect(tapiocaOFT0.connect(signer).removeTAP(signer.address, amount)).to.emit(tapiocaOFT0, 'Burned');
    });

    // it('should wrap some tokens', async () => {
    //     const amount = ethers.BigNumber.from('1000');

    //     const erc20Mock0BalanceOfSignerBeforeMint = await erc20Mock0.balanceOf(signer.address);
    //     await erc20Mock0.connect(signer).freeMint(amount);
    //     const erc20Mock0BalanceOfSignerAfterMint = await erc20Mock0.balanceOf(signer.address);

    //     expect(erc20Mock0BalanceOfSignerAfterMint.gt(erc20Mock0BalanceOfSignerBeforeMint)).to.be.true;
    //     expect(erc20Mock0BalanceOfSignerAfterMint).to.eq(amount);

    //     const oft0BalanceBeforeWrap = await tapiocaOFT0.balanceOf(signer.address);
    //     expect(oft0BalanceBeforeWrap).to.eq(0);

    //     await wrap(tapiocaOFT0, erc20Mock0, amount, signer, true); //revert
    //     await wrap(tapiocaOFT0, erc20Mock0, amount, signer);

    //     const oft0BalanceAfterWrap = await tapiocaOFT0.balanceOf(signer.address);
    //     expect(oft0BalanceAfterWrap).to.eq(amount);
    // });

    // it('should not wrap when paused', async () => {
    //     const amount = ethers.BigNumber.from('1000');
    //     await erc20Mock0.connect(signer).freeMint(amount);
    //     await erc20Mock0.connect(signer).freeMint(amount);
    //     await wrap(tapiocaOFT0, erc20Mock0, amount, signer);

    //     await tapiocaOFT0.pauseSendTokens(true);

    //     await wrap(tapiocaOFT0, erc20Mock0, amount, signer, true); //revert

    //     await tapiocaOFT0.pauseSendTokens(false);

    //     await wrap(tapiocaOFT0, erc20Mock0, amount, signer);
    // });

    // it('should unwrap', async () => {
    //     const amount = ethers.BigNumber.from('1000');
    //     await erc20Mock0.connect(signer).freeMint(amount);
    //     await wrap(tapiocaOFT0, erc20Mock0, amount, signer);

    //     await unwrap(tapiocaOFT0, amount.mul(2), signer, true); //revert
    //     await unwrap(tapiocaOFT0, amount, signer);
    // });

    // it('should not unwrap when paused', async () => {
    //     const amount = ethers.BigNumber.from('1000');
    //     await erc20Mock0.connect(signer).freeMint(amount);
    //     await wrap(tapiocaOFT0, erc20Mock0, amount, signer);

    //     await tapiocaOFT0.pauseSendTokens(true);

    //     await unwrap(tapiocaOFT0, amount.mul(2), signer, true); //revert

    //     await tapiocaOFT0.pauseSendTokens(false);

    //     await unwrap(tapiocaOFT0, amount, signer);
    // });
});

// async function wrap(
//     tapiocaOftContract: TapOFT,
//     erc20Contract: ERC20Mock,
//     amount: BigNumber,
//     signer: SignerWithAddress,
//     shouldRevert?: boolean,
// ) {
//     if (shouldRevert) {
//         await expect(tapiocaOftContract.connect(signer).wrap(signer.address, amount)).to.be.reverted;
//     } else {
//         await erc20Contract.approve(tapiocaOftContract.address, amount);
//         await expect(tapiocaOftContract.connect(signer).wrap(signer.address, amount)).to.emit(tapiocaOftContract, 'Wrap');
//     }
// }

// async function unwrap(tapiocaOftContract: TapOFT, amount: BigNumber, signer: SignerWithAddress, shouldRevert?: boolean) {
//     if (shouldRevert) {
//         await expect(tapiocaOftContract.connect(signer).unwrap(signer.address, amount)).to.be.reverted;
//     } else {
//         await expect(tapiocaOftContract.connect(signer).unwrap(signer.address, amount)).to.emit(tapiocaOftContract, 'Unwrap');
//     }
// }
