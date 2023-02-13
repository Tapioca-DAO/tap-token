import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import writeJsonFile from 'write-json-file';
import { LZEndpointMock, TapOFT } from '../../typechain/';
import { BigNumberish } from 'ethers';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { BN, deployLZEndpointMock, deployTapiocaOFT, time_travel } from '../test.utils';

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
        const totalSupply = BN(33_500_000).mul((1e18).toString());
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not be able to deploy with an empty LayerZero endpoint', async () => {
        const factory = await ethers.getContractFactory('TapOFT');
        await expect(factory.deploy(ethers.constants.AddressZero, signer.address, signer.address, signer.address, signer.address, 1)).to.be
            .reverted;
    });

    it('should set minter', async () => {
        const currentMinter = await tapiocaOFT0.minter();
        expect(currentMinter).to.eq(ethers.constants.AddressZero);
        await expect(tapiocaOFT0.connect(minter).setMinter(minter.address)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setMinter(ethers.constants.AddressZero)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');
    });

    it('should compute week based on timestamp correctly', async () => {
        const currentBlockTimestamp = (await ethers.provider.getBlock('latest')).timestamp;

        expect(await tapiocaOFT0.timestampToWeek(currentBlockTimestamp)).to.eq(1);
        for (let i = 1; i < 100; i++) {
            const week = await tapiocaOFT0.timestampToWeek((await tapiocaOFT0.WEEK()).mul(i).add(currentBlockTimestamp));
            expect(week).to.eq(i + 1);
        }
    });

    it('should not allow emit from another chain', async () => {
        const chainBLzEndpoint = await deployLZEndpointMock(11);
        const chainBTap = await deployTapiocaOFT(chainBLzEndpoint.address, signer.address, 10);
        await time_travel(7 * 86400);
        await expect(chainBTap.connect(signer).emitForWeek()).to.be.revertedWith('chain not valid');
    });

    it('should mint for each week', async () => {
        const balBefore = await tapiocaOFT0.balanceOf(tapiocaOFT0.address);
        await tapiocaOFT0.connect(normalUser).emitForWeek();
        const balAfter = await tapiocaOFT0.balanceOf(tapiocaOFT0.address);
        expect(balAfter).to.be.gt(balBefore);
        await tapiocaOFT0.connect(normalUser).emitForWeek();
        expect(await tapiocaOFT0.balanceOf(tapiocaOFT0.address)).to.be.equal(balAfter); // Can't mint 2 times a week

        await time_travel(7 * 86400);
        await expect(tapiocaOFT0.connect(normalUser).emitForWeek()).to.emit(tapiocaOFT0, 'Minted');
        expect(await tapiocaOFT0.balanceOf(tapiocaOFT0.address)).to.be.gt(balAfter); // Can mint after 7 days
    });

    it('should transfer unused TAP for next week', async () => {
        await tapiocaOFT0.connect(normalUser).emitForWeek();
        const balAfter = await tapiocaOFT0.balanceOf(tapiocaOFT0.address);
        await tapiocaOFT0.setMinter(minter.address);
        await tapiocaOFT0.connect(minter).extractTAP(minter.address, balAfter.div(2));

        const dso_supply = await tapiocaOFT0.dso_supply();
        const toBeEmitted = dso_supply.sub(balAfter.div(2)).mul(BN(8800000000000000)).div(BN((1e18).toString()));

        await time_travel(7 * 86400);
        await tapiocaOFT0.connect(normalUser).emitForWeek();
        expect(await tapiocaOFT0.balanceOf(tapiocaOFT0.address)).to.be.equal(toBeEmitted.add(balAfter.div(2)));
    });

    it('should extract minted from minter', async () => {
        const bigAmount = BN(33_500_000).mul((1e18).toString());
        await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.emit(tapiocaOFT0, 'Minted');

        await expect(tapiocaOFT0.connect(minter).extractTAP(minter.address, bigAmount)).to.be.revertedWith('unauthorized');
        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(minter).extractTAP(minter.address, 0)).to.be.revertedWith('amount not valid');
        await expect(tapiocaOFT0.connect(minter).extractTAP(minter.address, bigAmount)).to.be.revertedWith('exceeds allowable amount');

        const balance = await tapiocaOFT0.balanceOf(tapiocaOFT0.address);

        const initialUserBalance = await tapiocaOFT0.balanceOf(minter.address);
        await tapiocaOFT0.connect(minter).extractTAP(minter.address, balance);
        const afterExtractUserBalance = await tapiocaOFT0.balanceOf(minter.address);
        expect(afterExtractUserBalance.sub(initialUserBalance).eq(balance)).to.be.true;
    });

    it('should not mint when paused', async () => {
        await tapiocaOFT0.updatePause(true);
        await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.be.reverted;
        await tapiocaOFT0.updatePause(false);
        await time_travel(86400);
        await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.emit(tapiocaOFT0, 'Minted');
    });

    it('should burn', async () => {
        const toBurn = BN(10_000_000).mul((1e18).toString());
        const finalAmount = BN(23_500_000).mul((1e18).toString());

        await expect(tapiocaOFT0.connect(signer).setMinter(minter.address)).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(normalUser).removeTAP(toBurn)).to.be.reverted;
        await expect(tapiocaOFT0.connect(signer).removeTAP(toBurn)).to.emit(tapiocaOFT0, 'Burned');

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        expect(signerBalance).to.eq(finalAmount);

        const totalSupply = await tapiocaOFT0.totalSupply();
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not burn when paused', async () => {
        const amount = BN(33_500_000).mul((1e18).toString());
        await tapiocaOFT0.updatePause(true);
        await expect(tapiocaOFT0.connect(signer).removeTAP(amount)).to.be.reverted;
        await tapiocaOFT0.updatePause(false);
        await expect(tapiocaOFT0.connect(signer).removeTAP(amount)).to.emit(tapiocaOFT0, 'Burned');
    });

    it('should test weekly emissions', async () => {
        const noOfWeeks = 200;
        const supplyJsonContent: any = {};
        const emissionJsonContent: any = {};
        let sum: BigNumberish = 0;
        await tapiocaOFT0.connect(signer).setMinter(minter.address);
        for (let i = 1; i <= noOfWeeks; i++) {
            await time_travel(7 * 86400);
            await tapiocaOFT0.emitForWeek();
            const available = await tapiocaOFT0.callStatic.getCurrentWeekEmission();
            sum = available.add(sum);
            await tapiocaOFT0.connect(minter).extractTAP(signer.address, available);

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
