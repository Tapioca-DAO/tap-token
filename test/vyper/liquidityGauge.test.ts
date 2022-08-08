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
        expect(futureEpochTime.gt(0)).to.be.true; 
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

    it('should deposit and produce rewards when there are multiple gauges and types having the same initial weight, from 3 users', async () => {
        //SETUP
        const initialWeight = BN(1).mul((1e18).toString());
        const depositAmount = BN(20000).mul((1e18).toString());

        const erc20Mock2 = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(BN(2000000).mul((1e18).toString()));
        const erc20Mock3 = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(BN(2000000).mul((1e18).toString()));
        const liquidityGauge2 = (await deployLiquidityGauge(erc20Mock2.address, minter.address, signer.address)) as LiquidityGauge;
        const liquidityGauge3 = (await deployLiquidityGauge(erc20Mock3.address, minter.address, signer.address)) as LiquidityGauge;
        const liquidityGaugeInterface = await ethers.getContractAt('ILiquidityGauge', liquidityGauge.address);
        const liquidityGaugeInterface2 = await ethers.getContractAt('ILiquidityGauge', liquidityGauge2.address);
        const liquidityGaugeInterface3 = await ethers.getContractAt('ILiquidityGauge', liquidityGauge3.address);
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);

        const depositors = [signer, signer2, signer3];
        const tokens = [erc20Mock, erc20Mock2, erc20Mock3];
        const gauges = [liquidityGauge, liquidityGauge2, liquidityGauge3];
        const gaugesInterfaces = [liquidityGaugeInterface, liquidityGaugeInterface2, liquidityGaugeInterface3];

        //Add 3 gauges and 3 types
        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_type('Test2', initialWeight);
        await gaugeController.add_type('Test3', initialWeight);

        await gaugeController.add_gauge(liquidityGauge.address, 0, initialWeight);
        await gaugeController.add_gauge(liquidityGauge2.address, 0, initialWeight);
        await gaugeController.add_gauge(liquidityGauge3.address, 1, initialWeight);

        // gettokens
        for (var i = 0; i < 3; i++) {
            await tokens[i].connect(depositors[i]).freeMint(depositAmount);
            const balanceOfDepositor = await tokens[i].balanceOf(depositors[i].address);
            expect(balanceOfDepositor.eq(depositAmount), `token ${i}`).to.be.true;
        }

        //stake receipt tokens
        for (var i = 0; i < 3; i++) {
            await tokens[i].connect(depositors[i]).approve(gauges[i].address, depositAmount);
            await gaugesInterfaces[i].connect(depositors[i]).deposit(depositAmount, depositors[i].address);
            const balanceOfDepositor = await gauges[i].balanceOf(depositors[i].address);
            expect(balanceOfDepositor.eq(depositAmount), `liquidity balance ${i}`).to.be.true;
        }

        //time travel 100 days
        time_travel(100 * DAY);

        for (var i = 0; i < 3; i++) {
            const initialTapBalance = await tapiocaOFT.balanceOf(depositors[i].address);

            await gaugeControllerInterface.gauge_relative_weight_write(gauges[i].address);
            const gaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(gauges[i].address);
            expect(gaugeRelativeWeight.gt(0), `relative weight ${i}`).to.be.true;

            await minter.connect(depositors[i]).mint(gauges[i].address);

            const finalTapBalance = await tapiocaOFT.balanceOf(depositors[i].address);
            expect(finalTapBalance.gt(initialTapBalance), `tap balance ${i}`).to.be.true;
        }

        // withdraw from the third user
        const signerReceiptBalanceBeforeWithdraw = await erc20Mock3.balanceOf(signer3.address);
        expect(signerReceiptBalanceBeforeWithdraw.eq(0)).to.be.true;

        await liquidityGauge3.connect(signer3).withdraw(depositAmount);

        const signerReceiptBalanceAfterWithdraw = await erc20Mock3.balanceOf(signer3.address);

        expect(signerReceiptBalanceAfterWithdraw.eq(depositAmount)).to.be.true;
        expect(signerReceiptBalanceAfterWithdraw.gt(signerReceiptBalanceBeforeWithdraw)).to.be.true;
    });

    it("should deposit and produce rewards when there are multiple gauges and types having the same initial weight but with different users' stake", async () => {
        //SETUP
        const initialWeight = BN(1).mul((1e18).toString());
        const depositAmount = BN(20000).mul((1e18).toString());
        const depositAmount2 = BN(30000).mul((1e18).toString());
        const depositAmount3 = BN(40000).mul((1e18).toString());

        const erc20Mock2 = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(BN(2000000).mul((1e18).toString()));
        const erc20Mock3 = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(BN(2000000).mul((1e18).toString()));
        const liquidityGauge2 = (await deployLiquidityGauge(erc20Mock2.address, minter.address, signer.address)) as LiquidityGauge;
        const liquidityGauge3 = (await deployLiquidityGauge(erc20Mock3.address, minter.address, signer.address)) as LiquidityGauge;
        const liquidityGaugeInterface = await ethers.getContractAt('ILiquidityGauge', liquidityGauge.address);
        const liquidityGaugeInterface2 = await ethers.getContractAt('ILiquidityGauge', liquidityGauge2.address);
        const liquidityGaugeInterface3 = await ethers.getContractAt('ILiquidityGauge', liquidityGauge3.address);
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);

        const depositors = [signer, signer2, signer3];
        const tokens = [erc20Mock, erc20Mock2, erc20Mock3];
        const gauges = [liquidityGauge, liquidityGauge2, liquidityGauge3];
        const gaugesInterfaces = [liquidityGaugeInterface, liquidityGaugeInterface2, liquidityGaugeInterface3];
        const amounts = [depositAmount, depositAmount2, depositAmount3];

        //Add 3 gauges and 3 types
        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_type('Test2', initialWeight);
        await gaugeController.add_type('Test3', initialWeight);

        await gaugeController.add_gauge(liquidityGauge.address, 0, initialWeight);
        await gaugeController.add_gauge(liquidityGauge2.address, 0, initialWeight);
        await gaugeController.add_gauge(liquidityGauge3.address, 1, initialWeight);

        // gettokens
        for (var i = 0; i < 3; i++) {
            await tokens[i].connect(depositors[i]).freeMint(amounts[i]);
            const balanceOfDepositor = await tokens[i].balanceOf(depositors[i].address);
            expect(balanceOfDepositor.eq(amounts[i]), `token ${i}`).to.be.true;
        }

        //stake receipt tokens
        for (var i = 0; i < 3; i++) {
            await tokens[i].connect(depositors[i]).approve(gauges[i].address, amounts[i]);
            await gaugesInterfaces[i].connect(depositors[i]).deposit(amounts[i], depositors[i].address);
            const balanceOfDepositor = await gauges[i].balanceOf(depositors[i].address);
            expect(balanceOfDepositor.eq(amounts[i]), `liquidity balance ${i}`).to.be.true;
        }

        //time travel 100 days
        time_travel(100 * DAY);

        for (var i = 0; i < 3; i++) {
            const initialTapBalance = await tapiocaOFT.balanceOf(depositors[i].address);

            await gaugeControllerInterface.gauge_relative_weight_write(gauges[i].address);
            const gaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(gauges[i].address);
            expect(gaugeRelativeWeight.gt(0), `relative weight ${i}`).to.be.true;

            await minter.connect(depositors[i]).mint(gauges[i].address);

            const finalTapBalance = await tapiocaOFT.balanceOf(depositors[i].address);
            expect(finalTapBalance.gt(initialTapBalance), `tap balance ${i}`).to.be.true;
            if (i > 0) {
                let finalTapBalanceOfPrevious = await tapiocaOFT.balanceOf(depositors[i - 1].address);
                if (i == 1) {
                    finalTapBalanceOfPrevious = finalTapBalanceOfPrevious.sub(BN(100000000).mul((1e18).toString()));
                }
                expect(finalTapBalance.gt(finalTapBalanceOfPrevious), `tap balance vs previous ${i}`).to.be.true;
            }
        }

        // withdraw from the third user
        const signerReceiptBalanceBeforeWithdraw = await erc20Mock3.balanceOf(signer3.address);
        expect(signerReceiptBalanceBeforeWithdraw.eq(0)).to.be.true;

        await liquidityGauge3.connect(signer3).withdraw(amounts[2]);

        const signerReceiptBalanceAfterWithdraw = await erc20Mock3.balanceOf(signer3.address);

        expect(signerReceiptBalanceAfterWithdraw.eq(amounts[2])).to.be.true;
        expect(signerReceiptBalanceAfterWithdraw.gt(signerReceiptBalanceBeforeWithdraw)).to.be.true;
    });
});
