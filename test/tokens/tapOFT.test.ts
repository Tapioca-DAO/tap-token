import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import writeJsonFile from 'write-json-file';
import { TapOFT, LzEndpointMock } from '../../typechain/';
import { VeTap } from '../../typechain/contracts/vyper/VeTap.vy';

import { deployLZEndpointMock, deployTapiocaOFT, BN, time_travel } from '../test.utils';
import { BigNumberish } from 'ethers';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('tapOFT', () => {
    let signer: SignerWithAddress;
    let minter: SignerWithAddress;
    let normalUser: SignerWithAddress;

    let LZEndpointMockCurrentChain: LZEndpointMock;
    let LZEndpointMockGovernance: LZEndpointMock;

    let tapiocaOFT0: TapOFT;
    let tapiocaOFT1: TapOFT;


    async function register() {
        signer = (await ethers.getSigners())[0];
        minter = (await ethers.getSigners())[1];
        normalUser = (await ethers.getSigners())[2];

        const chainId = (await ethers.provider.getNetwork()).chainId;

        LZEndpointMockCurrentChain = (await deployLZEndpointMock(chainId)) as LZEndpointMock;
        LZEndpointMockGovernance = (await deployLZEndpointMock(11)) as LZEndpointMock;

        tapiocaOFT0 = (await deployTapiocaOFT(LZEndpointMockCurrentChain.address, signer.address)) as TapOFT;
        tapiocaOFT1 = (await deployTapiocaOFT(LZEndpointMockGovernance.address, signer.address)) as TapOFT;
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should check initial state', async () => {
        expect(await tapiocaOFT0.decimals()).eq(18);
        expect(await tapiocaOFT1.decimals()).eq(18);

        const chainId = (await ethers.provider.getNetwork()).chainId;
        expect(await LZEndpointMockCurrentChain.getChainId()).eq(chainId);
        expect(await LZEndpointMockGovernance.getChainId()).eq(11);

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
                1,
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

    it('should check availability for week', async () => {
        const timestampTooBig = await tapiocaOFT0.availableForWeek(99999999999999);
        expect(timestampTooBig.eq(0)).to.be.true;

        const timestampTooSmall = await tapiocaOFT0.availableForWeek(1);
        expect(timestampTooSmall.eq(0)).to.be.true;

        await time_travel(10 * 86400);
        let validAmount = await tapiocaOFT0.availableForWeek(0);
        expect(validAmount.gt(0)).to.be.true;

        const latestBlock = await ethers.provider.getBlock('latest');
        validAmount = await tapiocaOFT0.availableForWeek(latestBlock.timestamp);
        expect(validAmount.gt(0)).to.be.true;

        await expect(tapiocaOFT0.connect(normalUser).emitForWeek(0)).to.emit(tapiocaOFT0, 'Minted');
        validAmount = await tapiocaOFT0.availableForWeek(latestBlock.timestamp);
        expect(validAmount.eq(0)).to.be.true;

        validAmount = await tapiocaOFT0.availableForWeek(0);
        expect(validAmount.eq(0)).to.be.true;
    });

    it('should not allow emit from another chain', async () => {
        const chainBLzEndpoint = await deployLZEndpointMock(11);
        const chainBTap = await deployTapiocaOFT(chainBLzEndpoint.address, signer.address, 10);
        await time_travel(10 * 86400);

        let validAmount = await chainBTap.availableForWeek(0);
        expect(validAmount.gt(0)).to.be.true;

        await expect(chainBTap.connect(signer).emitForWeek(0)).to.be.revertedWith('chain not valid');
    });

    it('should be able to set new params for emissions formula', async () => {
        await expect(tapiocaOFT0.connect(normalUser).setAParam(100)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setAParam(100)).to.emit(tapiocaOFT0, 'AParamUpdated');

        await expect(tapiocaOFT0.connect(normalUser).setBParam(100)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setBParam(100)).to.emit(tapiocaOFT0, 'BParamUpdated');

        await expect(tapiocaOFT0.connect(normalUser).setCParam(100)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setCParam(100)).to.emit(tapiocaOFT0, 'CParamUpdated');
    });

    it('should mint more', async () => {
        const initialAmount = BN(100000000).mul((1e18).toString());
        await expect(tapiocaOFT0.connect(normalUser).emitForWeek(999999999999999)).to.be.revertedWith('timestamp not valid');
        await expect(tapiocaOFT0.connect(normalUser).emitForWeek(1)).to.be.revertedWith('timestamp not valid');

        await time_travel(50 * 86400);
        const initialEmission = await tapiocaOFT0.connect(signer).callStatic.emitForWeek(0);
        expect(initialEmission.gt(0)).to.be.true;

        await expect(tapiocaOFT0.connect(normalUser).emitForWeek(0)).to.emit(tapiocaOFT0, 'Minted');

        const sameWeekEmission = await tapiocaOFT0.connect(signer).callStatic.emitForWeek(0);
        expect(sameWeekEmission.eq(0)).to.be.true;

        const latestBlock = await ethers.provider.getBlock('latest');
        const sameWeekByTimestampEmission = await tapiocaOFT0.connect(signer).callStatic.emitForWeek(latestBlock.timestamp);
        expect(sameWeekByTimestampEmission.eq(0)).to.be.true;

        const supplyAfterMinting = await tapiocaOFT0.totalSupply();
        expect(supplyAfterMinting.gt(initialAmount)).to.be.true;

        const balanceOfContract = await tapiocaOFT0.balanceOf(tapiocaOFT0.address);
        expect(balanceOfContract.gt(0)).to.be.true;
    });

    it('should extract minted from owner', async () => {
        const bigAmount = BN(100000000).mul((1e18).toString());
        await time_travel(50 * 86400);
        await expect(tapiocaOFT0.connect(signer).emitForWeek(0)).to.emit(tapiocaOFT0, 'Minted');

        await expect(tapiocaOFT0.connect(normalUser).extractTAP(normalUser.address, 0)).to.be.revertedWith('unauthorized');

        await expect(tapiocaOFT0.connect(signer).extractTAP(ethers.constants.AddressZero, 0)).to.be.revertedWith('amount not valid');
        await expect(tapiocaOFT0.connect(signer).extractTAP(normalUser.address, bigAmount)).to.be.revertedWith('exceeds allowable amount');

        let balance = await tapiocaOFT0.balanceOf(tapiocaOFT0.address);

        const initialUserBalance = await tapiocaOFT0.balanceOf(normalUser.address);
        await tapiocaOFT0.connect(signer).extractTAP(normalUser.address, balance);
        const afteExtractUserBalance = await tapiocaOFT0.balanceOf(normalUser.address);
        expect(afteExtractUserBalance.sub(initialUserBalance).eq(balance)).to.be.true;
    });

    it('should extract minted from minter', async () => {
        const bigAmount = BN(100000000).mul((1e18).toString());
        await time_travel(50 * 86400);
        await expect(tapiocaOFT0.connect(signer).emitForWeek(0)).to.emit(tapiocaOFT0, 'Minted');

        await expect(tapiocaOFT0.connect(minter).extractTAP(normalUser.address, bigAmount)).to.be.revertedWith('unauthorized');

        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(minter).extractTAP(ethers.constants.AddressZero, 0)).to.be.revertedWith('amount not valid');
        await expect(tapiocaOFT0.connect(minter).extractTAP(normalUser.address, bigAmount)).to.be.revertedWith('exceeds allowable amount');

        let balance = await tapiocaOFT0.balanceOf(tapiocaOFT0.address);

        const initialUserBalance = await tapiocaOFT0.balanceOf(normalUser.address);
        await tapiocaOFT0.connect(minter).extractTAP(normalUser.address, balance);
        const afteExtractUserBalance = await tapiocaOFT0.balanceOf(normalUser.address);
        expect(afteExtractUserBalance.sub(initialUserBalance).eq(balance)).to.be.true;
    });

    it('should not mint when paused', async () => {
        await tapiocaOFT0.pauseSendTokens(true);
        await expect(tapiocaOFT0.connect(signer).emitForWeek(0)).to.be.reverted;
        await tapiocaOFT0.pauseSendTokens(false);
        await time_travel(50 * 86400);
        await expect(tapiocaOFT0.connect(signer).emitForWeek(0)).to.emit(tapiocaOFT0, 'Minted');
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

    it('should test weekly emissions', async () => {
        const noOfWeeks = 200;
        const supplyJsonContent: any = {};
        const emissionJsonContent: any = {};
        let sum: BigNumberish = 0;
        for (var i = 0; i <= noOfWeeks; i++) {
            await time_travel(7 * 86400);
            const available = await tapiocaOFT0.callStatic.emitForWeek(0);
            sum = available.add(sum);

            supplyJsonContent[i] = ethers.utils.formatEther(sum);
            emissionJsonContent[i] = ethers.utils.formatEther(available);
        }

        await writeJsonFile('test/tokens/extraSupplyPerWeek.json', supplyJsonContent);
        await writeJsonFile('test/tokens/emissionsPerWeek.json', emissionJsonContent);
    });

    it('should be able to set the governance chain identifier', async () => {
        await expect(tapiocaOFT0.connect(normalUser).setGovernanceChainIdentifier(4)).to.be.reverted;
        await tapiocaOFT0.connect(signer).setGovernanceChainIdentifier(4);
    });
});
