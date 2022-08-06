import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock, LZEndpointMock, LiquidityGauge, TapOFT, VeTap, GaugeController, Minter } from '../../typechain';

import {
    deployLZEndpointMock,
    deployTapiocaOFT,
    deployveTapiocaNFT,
    BN,
    time_travel,
    deployGaugeController,
    deployMinter,
    deployLiquidityGauge,
} from '../test.utils';
import { BigNumber } from 'ethers';

describe('liquidityGauge', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let signer3: SignerWithAddress;
    let erc20Mock: ERC20Mock;
    let LZEndpointMock: LZEndpointMock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let gaugeController: GaugeController;
    let minter: Minter;
    let liquidityGauge: LiquidityGauge;
    const DAY: number = 86400;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        signer3 = (await ethers.getSigners())[2];

        LZEndpointMock = (await deployLZEndpointMock(0)) as LZEndpointMock;
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, 'veTapioca Token', 'veTAP', '1')) as VeTap;
        gaugeController = (await deployGaugeController(tapiocaOFT.address, veTapioca.address)) as GaugeController;
        minter = (await deployMinter(tapiocaOFT.address, gaugeController.address)) as Minter;
        erc20Mock = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9));
        liquidityGauge = (await deployLiquidityGauge(erc20Mock.address, minter.address, signer.address)) as LiquidityGauge;

        await tapiocaOFT.setMinter(minter.address);
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should check initial state', async () => {
        const savedName = await liquidityGauge.name();
        expect(savedName).to.contain('tapioca.loan');

        const savedSymbol = await liquidityGauge.symbol();
        expect(savedSymbol).to.eq((await erc20Mock.symbol()) + '-gauge');

        const savedLpToken = await liquidityGauge.lp_token();
        expect(savedLpToken.toLowerCase()).to.eq(erc20Mock.address.toLowerCase());

        const savedMinter = await liquidityGauge.minter();
        expect(savedMinter.toLowerCase()).to.eq(minter.address.toLowerCase());

        const savedAdmin = await liquidityGauge.admin();
        expect(savedAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        const savedToken = await liquidityGauge.TAP_token();
        expect(savedToken.toLowerCase()).to.eq(tapiocaOFT.address.toLowerCase());

        const savedController = await liquidityGauge.controller();
        expect(savedController.toLowerCase()).to.eq(gaugeController.address.toLowerCase());

        const savedEscrow = await liquidityGauge.voting_escrow();
        expect(savedEscrow.toLowerCase()).to.eq(veTapioca.address.toLowerCase());

        const periodTimestamp = await liquidityGauge.period_timestamp(0);
        expect(periodTimestamp.gt(0)).to.be.true;

        const inflationRate = await liquidityGauge.inflation_rate();
        expect(inflationRate.eq(0)).to.be.true; //should be 0 before time pass

        const futureEpochTime = await liquidityGauge.future_epoch_time();
        //TODO: check future epoch time after code is implemented
    });

    it('should transfer ownersip', async () => {
        await expect(liquidityGauge.connect(signer2).commit_transfer_ownership(signer2.address)).to.be.revertedWith('unauthorized');

        await liquidityGauge.commit_transfer_ownership(signer2.address);

        const futureAdmin = await liquidityGauge.future_admin();
        expect(futureAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());

        await expect(liquidityGauge.connect(signer2).apply_transfer_ownership()).to.be.revertedWith('unauthorized');

        await liquidityGauge.apply_transfer_ownership();
        const finalAdmin = await liquidityGauge.admin();
        expect(finalAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());
    });

    it('should kill contract', async () => {
        const killStatus = await liquidityGauge.is_killed();
        expect(killStatus).to.be.false;

        await expect(liquidityGauge.connect(signer2).kill_me()).to.be.revertedWith('unauthorized');

        await liquidityGauge.kill_me();

        const killStatusAfter = await liquidityGauge.is_killed();
        expect(killStatusAfter).to.be.true;
    });

    it('should have initial checkpoint', async () => {
        const checkpoint = await liquidityGauge.integrate_checkpoint();
        const periodTimestamp = await liquidityGauge.period_timestamp(0);

        expect(checkpoint.eq(periodTimestamp)).to.be.true;
    });

    it('should have no values for non-participant', async () => {
        const integrateFn = await liquidityGauge.integrate_fraction(signer2.address);
        expect(integrateFn.eq(0)).to.be.true;

        const claimable = await liquidityGauge.connect(signer2).callStatic.claimable_tokens(signer2.address);
        expect(claimable.eq(0)).to.be.true;

        time_travel(10 * DAY);

        await expect(liquidityGauge.connect(signer3).user_checkpoint(signer2.address)).to.be.revertedWith('unauthorized');
        await liquidityGauge.connect(signer2).user_checkpoint(signer2.address);

        const integrateFnFinal = await liquidityGauge.integrate_fraction(signer2.address);
        expect(integrateFnFinal.eq(0)).to.be.true;

        const claimableFinal = await liquidityGauge.connect(signer2).callStatic.claimable_tokens(signer2.address);
        expect(claimableFinal.eq(0)).to.be.true;
    });

    it('should allow approval for another user', async () => {
        const approvedBefore = await liquidityGauge.approved_to_deposit(signer2.address, signer.address);
        expect(approvedBefore).to.be.false;

        await liquidityGauge.connect(signer).set_approve_deposit(signer2.address, true);

        const approvedAfter = await liquidityGauge.approved_to_deposit(signer2.address, signer.address);
        expect(approvedAfter).to.be.true;
    });

    it('should not kick non-participant', async () => {
        await expect(liquidityGauge.kick(signer2.address)).to.be.revertedWith('kick not needed');
    });

    it('should not be able to deposit without a token', async () => {
        const toTransfer = BN(10000).mul((1e18).toString());
        await tapiocaOFT.connect(signer).approve(liquidityGauge.address, toTransfer);

        const liquidityGaugeInterface = await ethers.getContractAt('ILiquidityGauge', liquidityGauge.address);
        await expect(liquidityGaugeInterface.connect(signer2).deposit(toTransfer, signer2.address)).to.be.reverted;
    });

    it('should not be able to deposit for someone else without approval', async () => {
        const toTransfer = BN(10000).mul((1e18).toString());
        const liquidityGaugeInterface = await ethers.getContractAt('ILiquidityGauge', liquidityGauge.address);

        await expect(liquidityGaugeInterface.connect(signer3).deposit(toTransfer, signer2.address)).to.be.revertedWith('unauthorized');
    });

    it('should not be able to withdraw without participating in the pool', async () => {
        const toTransfer = BN(10000).mul((1e18).toString());
        await expect(liquidityGauge.connect(signer3).withdraw(toTransfer)).to.be.reverted;
    });

  
});

//TODO: add minting tests
