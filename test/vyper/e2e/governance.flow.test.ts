import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import {
    ERC20Mock,
    LZEndpointMock,
    TapOFT,
    VeTap,
    GaugeController,
    FeeDistributor,
    TimedGauge,
    GaugeDistributor,
} from '../../../typechain';

import {
    deployLZEndpointMock,
    deployTapiocaOFT,
    deployveTapiocaNFT,
    BN,
    time_travel,
    deployGaugeController,
    deployFeeDistributor,
    deployTimedGauge,
    deployGaugeDistributor,
} from '../../test.utils';

describe.only('governance - flow', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let signer3: SignerWithAddress;
    let erc20Mock: ERC20Mock;
    let erc20Mock2: ERC20Mock;
    let LZEndpointMock: LZEndpointMock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let gaugeController: GaugeController;
    let gaugeDistributor: GaugeDistributor;
    let liquidityGauge: TimedGauge;
    let liquidityGauge2: TimedGauge;
    let feeDistributor: FeeDistributor;
    const DAY: number = 86400;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        signer3 = (await ethers.getSigners())[2];
        const latestBlock = await ethers.provider.getBlock('latest');

        LZEndpointMock = (await deployLZEndpointMock(0)) as LZEndpointMock;
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, 'veTapioca Token', 'veTAP', '1')) as VeTap;
        gaugeController = (await deployGaugeController(tapiocaOFT.address, veTapioca.address)) as GaugeController;
        gaugeDistributor = (await deployGaugeDistributor(tapiocaOFT.address, gaugeController.address)) as GaugeDistributor;
        erc20Mock = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9));
        erc20Mock2 = await (await hre.ethers.getContractFactory('ERC20Mock')).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9));
        liquidityGauge = (await deployTimedGauge(
            erc20Mock.address,
            tapiocaOFT.address,
            signer.address,
            gaugeDistributor.address,
        )) as TimedGauge;
        liquidityGauge2 = (await deployTimedGauge(
            erc20Mock2.address,
            tapiocaOFT.address,
            signer.address,
            gaugeDistributor.address,
        )) as TimedGauge;
        feeDistributor = (await deployFeeDistributor(
            veTapioca.address,
            latestBlock.timestamp,
            tapiocaOFT.address,
            signer.address,
            signer2.address,
        )) as FeeDistributor;

        await tapiocaOFT.setMinter(gaugeDistributor.address);
    });

    it('should lock in the escrow and cast vote using the gauge controller', async () => {
        const votingPower = 5000; //50%
        const amountToLock = BN(10000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const unlockTime: number = 4 * 365 * DAY; //max time

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + unlockTime);

        await gaugeController.add_type('Test', 0);
        await gaugeController.add_gauge(liquidityGauge.address, 0, 0);

        await gaugeController.connect(signer).vote_for_gauge_weights(liquidityGauge.address, votingPower);
        const lastUserVoteAfter = await gaugeController.last_user_vote(signer.address, liquidityGauge.address);
        expect(lastUserVoteAfter.gt(0)).to.be.true;

        const powerUsedAfterFirstVote = await gaugeController.vote_user_power(signer.address);
        const gaugeWeightAfterFirstVote = await gaugeController.get_gauge_weight(liquidityGauge.address);
        expect(gaugeWeightAfterFirstVote.gt(0)).to.be.true;
        expect(powerUsedAfterFirstVote.gt(0)).to.be.true;

        //100 days
        for (var i = 0; i <= 14; i++) {
            time_travel(7 * DAY);
            await tapiocaOFT.connect(signer).emitForWeek(0);
        }

        await gaugeController.connect(signer).vote_for_gauge_weights(liquidityGauge.address, votingPower);

        const powerUsedAfterSecondVote = await gaugeController.vote_user_power(signer.address);
        const gaugeWeightAfterSecondVote = await gaugeController.get_gauge_weight(liquidityGauge.address);
        expect(gaugeWeightAfterSecondVote.gt(0)).to.be.true;
        expect(powerUsedAfterSecondVote.gt(0)).to.be.true;

        time_travel(100 * DAY);

        await gaugeController.connect(signer).vote_for_gauge_weights(liquidityGauge.address, 2 * votingPower);
        const powerUsedAfterThirdVote = await gaugeController.vote_user_power(signer.address);
        const gaugeWeightAfterThirdVote = await gaugeController.get_gauge_weight(liquidityGauge.address);

        expect(gaugeWeightAfterThirdVote.gt(0)).to.be.true;
        expect(gaugeWeightAfterThirdVote.gt(gaugeWeightAfterFirstVote)).to.be.true;
        expect(powerUsedAfterThirdVote.gt(powerUsedAfterFirstVote)).to.be.true;
    });

    it.only('should lock, cast vote and have multiple users staking in various liquidity gauges', async () => {
        const votingPower = 5000; //50%
        const amountToLock = BN(10000).mul((1e18).toString());
        const feeAmount = BN(1000).mul((1e18).toString());
        const latestBlock = await ethers.provider.getBlock('latest');
        const unlockTime: number = 4 * 365 * DAY; //max time
        const erc20VotingEscrow = await ethers.getContractAt('IOFT', veTapioca.address);
        const liquidityGaugeInterface = await ethers.getContractAt('ILiquidityGauge', liquidityGauge.address);
        const liquidityGaugeInterface2 = await ethers.getContractAt('ILiquidityGauge', liquidityGauge2.address);
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);
        const feeDistributorInterface = await ethers.getContractAt('IFeeDistributor', feeDistributor.address);

        await liquidityGauge.unpause();
        await liquidityGauge2.unpause();
        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + unlockTime);

        await tapiocaOFT.connect(signer).transfer(signer2.address, amountToLock);
        await tapiocaOFT.connect(signer2).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer2).create_lock(amountToLock, latestBlock.timestamp + unlockTime);

        const balanceOfVeTokens = await erc20VotingEscrow.balanceOf(signer.address);
        expect(balanceOfVeTokens.gt(0)).to.be.true;

        time_travel(25 * DAY);

        const balanceOfVeTokensAfter25Days = await erc20VotingEscrow.balanceOf(signer.address);
        expect(balanceOfVeTokens.gt(balanceOfVeTokensAfter25Days)).to.be.true;

        //add types and gauges
        const initialWeight = BN(1).mul((1e18).toString());
        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_gauge(liquidityGauge.address, 0, initialWeight);
        await gaugeController.add_gauge(liquidityGauge2.address, 0, initialWeight);

        await gaugeController.vote_for_gauge_weights(liquidityGauge.address, votingPower); //this should produce more rewards

        //get receipt balances (simulating mixologist receipts)
        await erc20Mock.connect(signer).freeMint(amountToLock);
        await erc20Mock2.connect(signer2).freeMint(amountToLock);

        const signerReceiptBalance = await erc20Mock.balanceOf(signer.address);
        const signer2ReceiptBalance = await erc20Mock2.balanceOf(signer2.address);
        expect(signerReceiptBalance.gt(0)).to.be.true;
        expect(signer2ReceiptBalance.gt(0)).to.be.true;

        //deposit into the liquidity gauge
        await erc20Mock.connect(signer).approve(liquidityGauge.address, amountToLock);
        await liquidityGaugeInterface.connect(signer).deposit(amountToLock);

        await erc20Mock2.connect(signer2).approve(liquidityGauge2.address, amountToLock);
        await liquidityGaugeInterface2.connect(signer2).deposit(amountToLock);

        await gaugeControllerInterface.gauge_relative_weight_write(liquidityGauge.address);
        await gaugeControllerInterface.gauge_relative_weight_write(liquidityGauge2.address);

        //100 days
        for (var i = 0; i <= 14; i++) {
            time_travel(7 * DAY);
            await tapiocaOFT.connect(signer).emitForWeek(0);
            await gaugeDistributor.pushRewards(liquidityGauge.address);
            await gaugeDistributor.pushRewards(liquidityGauge2.address);
        }

        await liquidityGauge.connect(signer).claimRewards();
        await liquidityGauge2.connect(signer2).claimRewards();

        const signerTapBalance = await tapiocaOFT.balanceOf(signer.address);
        const signer2TapBalance = await tapiocaOFT.balanceOf(signer2.address);
        expect(signerTapBalance.gt(0), 'tap balance 1').to.be.true;
        expect(signer2TapBalance.gt(0), 'tap balance 2').to.be.true;
        expect(signerTapBalance.gt(signer2TapBalance)).to.be.true; //this had a vote so produced more rewards

        //simulate FeeDistributor fees
        let crtBLock = await ethers.provider.getBlock('latest');
        let veBalanceReportedByFeeSharingForSigner = await feeDistributor.ve_for_at(signer.address, crtBLock.timestamp);
        let veBalanceReportedByFeeSharingForSigner2 = await feeDistributor.ve_for_at(signer2.address, crtBLock.timestamp);
        expect(veBalanceReportedByFeeSharingForSigner.gt(0), 've balance 1').to.be.true;
        expect(veBalanceReportedByFeeSharingForSigner2.gt(0), 've balance 2').to.be.true;

        await tapiocaOFT.connect(signer).approve(feeDistributor.address, feeAmount);
        await tapiocaOFT.connect(signer).transfer(feeDistributor.address, feeAmount); //normal flow: beachBar.withdrawAllProtocolFees(..)

        const feeDistributorBalance = await tapiocaOFT.balanceOf(feeDistributor.address);
        expect(feeDistributorBalance.eq(feeAmount)).to.be.true;

        time_travel(2 * DAY);
        crtBLock = await ethers.provider.getBlock('latest');
        veBalanceReportedByFeeSharingForSigner2 = await feeDistributor.ve_for_at(signer2.address, crtBLock.timestamp);

        expect(veBalanceReportedByFeeSharingForSigner2.gt(0)).to.be.true;

        await feeDistributorInterface.connect(signer2).claim(signer2.address, false);

        const signer2TapBalanceAfterClaim = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceAfterClaim.gt(signer2TapBalance)).to.be.true;
    });
});
