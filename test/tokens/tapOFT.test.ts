import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import writeJsonFile from 'write-json-file';
import { LZEndpointMock, TapOFT } from '../../typechain/';
import { BigNumberish, Wallet } from 'ethers';
import {
    loadFixture,
    takeSnapshot,
} from '@nomicfoundation/hardhat-network-helpers';
import {
    BN,
    deployLZEndpointMock,
    deployTapiocaOFT,
    getERC20PermitSignature,
    time_travel,
} from '../test.utils';

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

        LZEndpointMockCurrentChain = (await deployLZEndpointMock(
            chainId,
        )) as LZEndpointMock;
        LZEndpointMockGovernance = (await deployLZEndpointMock(
            11,
        )) as LZEndpointMock;

        tapiocaOFT0 = (await deployTapiocaOFT(
            LZEndpointMockCurrentChain.address,
            signer.address,
        )) as TapOFT;
        tapiocaOFT1 = (await deployTapiocaOFT(
            LZEndpointMockGovernance.address,
            signer.address,
        )) as TapOFT;
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
        const totalSupply = BN(43_500_000).mul((1e18).toString());
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
                1,
            ),
        ).to.be.reverted;
    });

    it('should set minter', async () => {
        const currentMinter = await tapiocaOFT0.minter();
        expect(currentMinter).to.eq(ethers.constants.AddressZero);
        await expect(tapiocaOFT0.connect(minter).setMinter(minter.address)).to
            .be.reverted;
        await expect(
            tapiocaOFT0.connect(signer).setMinter(ethers.constants.AddressZero),
        ).to.be.reverted;
        await expect(
            tapiocaOFT0.connect(signer).setMinter(minter.address),
        ).to.emit(tapiocaOFT0, 'MinterUpdated');
    });

    it('should compute week based on timestamp correctly', async () => {
        const currentBlockTimestamp = (await ethers.provider.getBlock('latest'))
            .timestamp;

        expect(await tapiocaOFT0.timestampToWeek(currentBlockTimestamp)).to.eq(
            1,
        );
        for (let i = 1; i < 100; i++) {
            const week = await tapiocaOFT0.timestampToWeek(
                (await tapiocaOFT0.WEEK()).mul(i).add(currentBlockTimestamp),
            );
            expect(week).to.eq(i + 1);
        }
    });

    it('should not allow emit from another chain', async () => {
        const chainBLzEndpoint = await deployLZEndpointMock(11);
        const chainBTap = await deployTapiocaOFT(
            chainBLzEndpoint.address,
            signer.address,
            10,
        );
        await time_travel(7 * 86400);
        await expect(
            chainBTap.connect(signer).emitForWeek(),
        ).to.be.revertedWith('chain not valid');
    });

    it('should emit for each week', async () => {
        const initialDSOSupply = await tapiocaOFT0.dso_supply();

        const emissionForWeekBefore =
            await tapiocaOFT0.getCurrentWeekEmission();
        await tapiocaOFT0.connect(normalUser).emitForWeek();
        const emissionForWeekAfter = await tapiocaOFT0.getCurrentWeekEmission();
        expect(emissionForWeekAfter).to.be.gt(emissionForWeekBefore);

        await tapiocaOFT0.connect(normalUser).emitForWeek();
        expect(await tapiocaOFT0.getCurrentWeekEmission()).to.be.equal(
            emissionForWeekAfter,
        ); // Can't mint 2 times a week

        await time_travel(7 * 86400);
        await expect(tapiocaOFT0.connect(normalUser).emitForWeek()).to.emit(
            tapiocaOFT0,
            'Emitted',
        );
        expect(await tapiocaOFT0.getCurrentWeekEmission()).to.be.gt(
            emissionForWeekAfter,
        ); // Can mint after 7 days

        // DSO supply doesn't change if not extracted
        expect(await tapiocaOFT0.dso_supply()).to.be.equal(initialDSOSupply);
    });

    it('should extract minted from minter', async () => {
        const bigAmount = BN(33_500_000).mul((1e18).toString());
        // Check requirements
        await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.emit(
            tapiocaOFT0,
            'Emitted',
        );

        await expect(
            tapiocaOFT0.connect(minter).extractTAP(minter.address, bigAmount),
        ).to.be.revertedWith('unauthorized');
        await expect(
            tapiocaOFT0.connect(signer).setMinter(minter.address),
        ).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(
            tapiocaOFT0.connect(minter).extractTAP(minter.address, 0),
        ).to.be.revertedWith('amount not valid');
        await expect(
            tapiocaOFT0.connect(minter).extractTAP(minter.address, bigAmount),
        ).to.be.revertedWith('exceeds allowable amount');

        // Check balance
        const emissionForWeek = await tapiocaOFT0.getCurrentWeekEmission();
        const initialUserBalance = await tapiocaOFT0.balanceOf(minter.address);
        await tapiocaOFT0
            .connect(minter)
            .extractTAP(minter.address, emissionForWeek);
        const afterExtractUserBalance = await tapiocaOFT0.balanceOf(
            minter.address,
        );
        expect(
            afterExtractUserBalance.sub(initialUserBalance).eq(emissionForWeek),
        ).to.be.true;

        // Check state changes
        const currentWeek = await tapiocaOFT0.getCurrentWeek();
        const mintedInCurrentWeek = await tapiocaOFT0.mintedInWeek(currentWeek);
        expect(mintedInCurrentWeek).to.be.equal(emissionForWeek);
    });

    it('should transfer unused TAP for next week', async () => {
        await tapiocaOFT0.connect(normalUser).emitForWeek();
        const emissionWeek1 = await tapiocaOFT0.getCurrentWeekEmission();
        await tapiocaOFT0.setMinter(minter.address);
        await tapiocaOFT0
            .connect(minter)
            .extractTAP(minter.address, emissionWeek1.div(2));

        const dso_supply = await tapiocaOFT0.dso_supply();
        const toBeEmitted = dso_supply
            .sub(emissionWeek1.div(2))
            .mul(BN(8800000000000000))
            .div(BN((1e18).toString()));

        // Check emission update that accounts for unminted TAP
        await time_travel(7 * 86400);
        await tapiocaOFT0.connect(normalUser).emitForWeek();
        expect(await tapiocaOFT0.getCurrentWeekEmission()).to.be.equal(
            toBeEmitted.add(emissionWeek1.div(2)),
        );

        // Check DSO supply update
        expect(await tapiocaOFT0.dso_supply()).to.be.equal(
            dso_supply.sub(emissionWeek1.div(2)),
        );
    });

    it('should not mint when paused', async () => {
        await tapiocaOFT0.updatePause(true);
        await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.be.reverted;
        await tapiocaOFT0.updatePause(false);
        await time_travel(86400);
        await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.emit(
            tapiocaOFT0,
            'Emitted',
        );
    });

    it('should burn', async () => {
        const toBurn = BN(10_000_000).mul((1e18).toString());
        const finalAmount = BN(33_500_000).mul((1e18).toString());

        await expect(
            tapiocaOFT0.connect(signer).setMinter(minter.address),
        ).to.emit(tapiocaOFT0, 'MinterUpdated');

        await expect(tapiocaOFT0.connect(normalUser).removeTAP(toBurn)).to.be
            .reverted;
        await expect(tapiocaOFT0.connect(signer).removeTAP(toBurn)).to.emit(
            tapiocaOFT0,
            'Burned',
        );

        const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
        expect(signerBalance).to.eq(finalAmount);

        const totalSupply = await tapiocaOFT0.totalSupply();
        expect(signerBalance).to.eq(totalSupply);
    });

    it('should not burn when paused', async () => {
        const amount = BN(33_500_000).mul((1e18).toString());
        await tapiocaOFT0.updatePause(true);
        await expect(tapiocaOFT0.connect(signer).removeTAP(amount)).to.be
            .reverted;
        await tapiocaOFT0.updatePause(false);
        await expect(tapiocaOFT0.connect(signer).removeTAP(amount)).to.emit(
            tapiocaOFT0,
            'Burned',
        );
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
            const available =
                await tapiocaOFT0.callStatic.getCurrentWeekEmission();
            sum = available.add(sum);
            await tapiocaOFT0
                .connect(minter)
                .extractTAP(signer.address, available);

            supplyJsonContent[i] = ethers.utils.formatEther(sum);
            emissionJsonContent[i] = ethers.utils.formatEther(available);
        }

        await writeJsonFile(
            'test/tokens/extraSupplyPerWeek.json',
            supplyJsonContent,
        );
        await writeJsonFile(
            'test/tokens/emissionsPerWeek.json',
            emissionJsonContent,
        );
    });

    it('should be able to set the governance chain identifier', async () => {
        await expect(
            tapiocaOFT0.connect(normalUser).setGovernanceChainIdentifier(4),
        ).to.be.reverted;
        await tapiocaOFT0.connect(signer).setGovernanceChainIdentifier(4);
    });

    it('Should be able to use permit', async () => {
        const deadline =
            (await ethers.provider.getBlock('latest')).timestamp + 10_000;
        const { v, r, s } = await getERC20PermitSignature(
            signer,
            tapiocaOFT0,
            normalUser.address,
            (1e18).toString(),
            BN(deadline),
        );

        // Check if it works
        const snapshot = await takeSnapshot();
        await expect(
            tapiocaOFT0.permit(
                signer.address,
                normalUser.address,
                (1e18).toString(),
                deadline,
                v,
                r,
                s,
            ),
        )
            .to.emit(tapiocaOFT0, 'Approval')
            .withArgs(signer.address, normalUser.address, (1e18).toString());

        // Check that it can't be used twice
        await expect(
            tapiocaOFT0.permit(
                signer.address,
                normalUser.address,
                (1e18).toString(),
                deadline,
                v,
                r,
                s,
            ),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used after deadline
        await time_travel(10_001);
        await expect(
            tapiocaOFT0.permit(
                signer.address,
                normalUser.address,
                (1e18).toString(),
                deadline,
                v,
                r,
                s,
            ),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used with wrong signature
        const {
            v: v2,
            r: r2,
            s: s2,
        } = await getERC20PermitSignature(
            signer,
            tapiocaOFT0,
            minter.address,
            (1e18).toString(),
            BN(deadline),
        );
        await expect(
            tapiocaOFT0.permit(
                signer.address,
                normalUser.address,
                (1e18).toString(),
                deadline,
                v2,
                r2,
                s2,
            ),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can be batch called
        const permit = tapiocaOFT0.interface.encodeFunctionData('permit', [
            signer.address,
            normalUser.address,
            (1e18).toString(),
            deadline,
            v,
            r,
            s,
        ]);
        const transfer = tapiocaOFT0.interface.encodeFunctionData(
            'transferFrom',
            [signer.address, normalUser.address, (1e18).toString()],
        );

        await expect(
            tapiocaOFT0.connect(normalUser).batch([permit, transfer], true),
        )
            .to.emit(tapiocaOFT0, 'Transfer')
            .withArgs(signer.address, normalUser.address, (1e18).toString());
    });
});
