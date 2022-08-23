import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { LZEndpointMock, GaugeDistributor, TapOFT, VeTap, GaugeController } from '../typechain';

import {
    deployLZEndpointMock,
    deployTapiocaOFT,
    deployveTapiocaNFT,
    BN,
    time_travel,
    deployGaugeController,
    deployGaugeDistributor,
} from './test.utils';

describe('gaugeDistributor', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let mockedLiquidityGauge: any;
    let LZEndpointMock: LZEndpointMock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let gaugeController: GaugeController;
    let gaugeDistributor: GaugeDistributor;
    const DAY: number = 86400;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        const latestBlock = await ethers.provider.getBlock('latest');

        LZEndpointMock = (await deployLZEndpointMock(0)) as LZEndpointMock;
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, 'veTapioca Token', 'veTAP', '1')) as VeTap;
        gaugeController = (await deployGaugeController(tapiocaOFT.address, veTapioca.address)) as GaugeController;
        gaugeDistributor = (await deployGaugeDistributor(tapiocaOFT.address, gaugeController.address)) as GaugeDistributor;

        const mockedLiquidityGaugeFactory = await ethers.getContractFactory('LiquidityMockGauge');
        mockedLiquidityGauge = await mockedLiquidityGaugeFactory.connect(signer).deploy();
        await mockedLiquidityGauge.setToken(tapiocaOFT.address);
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should check initial state', async () => {
        const savedAdmin = await gaugeDistributor.owner();
        expect(savedAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        const savedToken = await gaugeDistributor.token();
        expect(savedToken.toLowerCase()).to.eq(tapiocaOFT.address.toLowerCase());

        const savedController = await gaugeDistributor.controller();
        expect(savedController.toLowerCase()).to.eq(gaugeController.address.toLowerCase());
    });

    it("should not create a contract without right params", async () => {
        const factory = await ethers.getContractFactory("GaugeDistributor");
        await expect(factory.deploy(ethers.constants.AddressZero, gaugeController.address)).to.be.reverted;
        await expect(factory.deploy(tapiocaOFT.address, ethers.constants.AddressZero)).to.be.reverted;
    });

    it('should not let the owner renounce ownership', async () => {
        await expect(gaugeDistributor.connect(signer).renounceOwnership()).to.be.revertedWith('unauthorized');
    });

    it('should check available rewards each week', async () => {
        const noOfWeeks = 10;
        const initialWeight = BN(1).mul((1e18).toString());
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);

        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, initialWeight);

        await tapiocaOFT.setMinter(gaugeDistributor.address);

        const availableWhenGaugeDoesNotExist = await gaugeDistributor.availableRewards(signer.address, 0);
        expect(availableWhenGaugeDoesNotExist.eq(0)).to.be.true;

        let latestBlock = await ethers.provider.getBlock('latest');
        for (var i = 0; i <= noOfWeeks; i++) {
            time_travel(7 * DAY);
            await gaugeControllerInterface.gauge_relative_weight_write(mockedLiquidityGauge.address);
            const gaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(mockedLiquidityGauge.address);
            expect(gaugeRelativeWeight.gt(0), 'weight').to.be.true;

            const tapSupplyBefore = await tapiocaOFT.totalSupply();
            await tapiocaOFT.connect(signer).emitForWeek(0);
            const tapSupplyAfter = await tapiocaOFT.totalSupply();
            expect(tapSupplyAfter.gt(tapSupplyBefore), 'TAP supply').to.be.true;

            latestBlock = await ethers.provider.getBlock('latest');
            const available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
            expect(available.gt(0), 'available').to.be.true;
        }
    });

    it("shouldn't let anyone add rewards twice for the same week", async () => {
        const initialWeight = BN(1).mul((1e18).toString());
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);

        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, initialWeight);
        await tapiocaOFT.setMinter(gaugeDistributor.address);

        time_travel(7 * DAY);
        await gaugeControllerInterface.gauge_relative_weight_write(mockedLiquidityGauge.address);
        const tapSupplyBefore = await tapiocaOFT.totalSupply();
        await tapiocaOFT.connect(signer).emitForWeek(0);
        const tapSupplyAfter = await tapiocaOFT.totalSupply();
        expect(tapSupplyAfter.gt(tapSupplyBefore), 'TAP supply').to.be.true;

        let latestBlock = await ethers.provider.getBlock('latest');

        let available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
        expect(available.gt(0), 'available before').to.be.true;

        const tapBalanceBefore = await tapiocaOFT.balanceOf(tapiocaOFT.address);
        await gaugeDistributor.pushRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
        const tapBalanceAfter = await tapiocaOFT.balanceOf(tapiocaOFT.address);
        const gaugeBalance = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
        expect(gaugeBalance.eq(tapBalanceBefore.sub(tapBalanceAfter))).to.be.true;

        available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
        expect(available.eq(0), 'available after').to.be.true;

        time_travel(7 * DAY);
        latestBlock = await ethers.provider.getBlock('latest');
        await gaugeControllerInterface.gauge_relative_weight_write(mockedLiquidityGauge.address);
        await tapiocaOFT.connect(signer).emitForWeek(0);
        available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
        expect(available.gt(0), 'available next week').to.be.true;
    })

    it("should be able to emit after week passed and rewards to be added to the gauge", async () => {
        const initialWeight = BN(1).mul((1e18).toString());
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);

        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, initialWeight);
        await tapiocaOFT.setMinter(gaugeDistributor.address);

        time_travel(7 * DAY);
        await gaugeControllerInterface.gauge_relative_weight_write(mockedLiquidityGauge.address);
        const firstWeekBlock = await ethers.provider.getBlock('latest');

        time_travel(7 * DAY);
        await gaugeControllerInterface.gauge_relative_weight_write(mockedLiquidityGauge.address);
        const secondWeekBlock = await ethers.provider.getBlock('latest');

        let available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, firstWeekBlock.timestamp);
        expect(available.eq(0), 'available first week').to.be.true;

        available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, secondWeekBlock.timestamp);
        expect(available.eq(0), 'available second week').to.be.true;

        await tapiocaOFT.connect(signer).emitForWeek(firstWeekBlock.timestamp);
        available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, firstWeekBlock.timestamp);
        expect(available.gt(0), 'available first week after emit').to.be.true;
        await gaugeDistributor.pushRewards(mockedLiquidityGauge.address, firstWeekBlock.timestamp);
        available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, firstWeekBlock.timestamp);
        expect(available.eq(0), 'available first week after push').to.be.true;

        const gaugeBalanceFirstWeek = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
        await gaugeDistributor.pushRewards(mockedLiquidityGauge.address, firstWeekBlock.timestamp);
        let gaugeBalance = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
        expect(gaugeBalance.eq(gaugeBalanceFirstWeek)).to.be.true;


        await tapiocaOFT.connect(signer).emitForWeek(secondWeekBlock.timestamp);
        available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, secondWeekBlock.timestamp);
        expect(available.gt(0), 'available second week after emit').to.be.true;
        await gaugeDistributor.pushRewards(mockedLiquidityGauge.address, secondWeekBlock.timestamp);
        available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, secondWeekBlock.timestamp);
        expect(available.eq(0), 'available second week after push').to.be.true;
    })


    it('should add rewards weekly', async () => {
        const noOfWeeks = 10;
        const initialWeight = BN(1).mul((1e18).toString());
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);

        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, initialWeight);

        await tapiocaOFT.setMinter(gaugeDistributor.address);
        const tapInitialSupply = await tapiocaOFT.totalSupply();
        let latestBlock = await ethers.provider.getBlock('latest');
        for (var i = 0; i <= noOfWeeks; i++) {
            time_travel(7 * DAY);
            await gaugeControllerInterface.gauge_relative_weight_write(mockedLiquidityGauge.address);
            const gaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(mockedLiquidityGauge.address);
            expect(gaugeRelativeWeight.gt(0), 'weight').to.be.true;

            const tapSupplyBefore = await tapiocaOFT.totalSupply();
            await tapiocaOFT.connect(signer).emitForWeek(0);
            const tapSupplyAfter = await tapiocaOFT.totalSupply();
            expect(tapSupplyAfter.gt(tapSupplyBefore), 'TAP supply').to.be.true;

            latestBlock = await ethers.provider.getBlock('latest');
            const available = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
            expect(available.gt(0), 'available').to.be.true;

            const gaugeBalanceBefore = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
            await gaugeDistributor.pushRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
            const gaugeBalanceAfter = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
            const addedToGauge = gaugeBalanceAfter.sub(gaugeBalanceBefore);
            const emittedThisWeek = tapSupplyAfter.sub(tapSupplyBefore);
            expect(addedToGauge.eq(emittedThisWeek), 'added').to.be.true;
        }
        const tapFinalSupply = await tapiocaOFT.totalSupply();

        const totalAdded = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
        expect(totalAdded.eq(tapFinalSupply.sub(tapInitialSupply)), `total added`).to.be.true;
    });

    it('should mint many rewards weekly', async () => {
        const noOfWeeks = 10;
        const initialWeight = BN(1).mul((1e18).toString());
        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);

        //Second gauge - needs deployment
        const mockedLiquidityGaugeFactory = await ethers.getContractFactory('LiquidityMockGauge');
        const anotherLiquidityGauge = await mockedLiquidityGaugeFactory.connect(signer).deploy();
        await anotherLiquidityGauge.setToken(tapiocaOFT.address);

        await gaugeController.add_type('Test', initialWeight);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, initialWeight);
        await gaugeController.add_gauge(anotherLiquidityGauge.address, 0, initialWeight);

        await tapiocaOFT.setMinter(gaugeDistributor.address);
        const tapInitialSupply = await tapiocaOFT.totalSupply();
        let latestBlock = await ethers.provider.getBlock('latest');
        for (var i = 0; i <= noOfWeeks; i++) {
            time_travel(7 * DAY);
            await gaugeControllerInterface.gauge_relative_weight_write(mockedLiquidityGauge.address);
            await gaugeControllerInterface.gauge_relative_weight_write(anotherLiquidityGauge.address);
            const gaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(mockedLiquidityGauge.address);
            expect(gaugeRelativeWeight.gt(0), 'weight 1').to.be.true;
            const anotherGaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(anotherLiquidityGauge.address);
            expect(anotherGaugeRelativeWeight.gt(0), 'weight 2').to.be.true;

            const tapSupplyBefore = await tapiocaOFT.totalSupply();
            await tapiocaOFT.connect(signer).emitForWeek(0);
            const tapSupplyAfter = await tapiocaOFT.totalSupply();
            expect(tapSupplyAfter.gt(tapSupplyBefore), 'TAP supply').to.be.true;

            latestBlock = await ethers.provider.getBlock('latest');
            const available1 = await gaugeDistributor.availableRewards(mockedLiquidityGauge.address, latestBlock.timestamp);
            expect(available1.gt(0), 'available').to.be.true;

            const available2 = await gaugeDistributor.availableRewards(anotherLiquidityGauge.address, latestBlock.timestamp);
            expect(available2.gt(0), 'available').to.be.true;

            const gaugeBalanceBefore = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
            await gaugeDistributor.pushRewardsToMany([
                mockedLiquidityGauge.address,
                anotherLiquidityGauge.address,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
            ], latestBlock.timestamp);
            const gaugeBalanceAfter = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
            const addedToGauge = gaugeBalanceAfter.sub(gaugeBalanceBefore);
            const emittedThisWeek = tapSupplyAfter.sub(tapSupplyBefore);

            expect(emittedThisWeek.gt(addedToGauge), 'added').to.be.true;
        }
        const tapFinalSupply = await tapiocaOFT.totalSupply();

        const totalAdded1 = await tapiocaOFT.balanceOf(mockedLiquidityGauge.address);
        const totalAdded2 = await tapiocaOFT.balanceOf(anotherLiquidityGauge.address);
        expect(totalAdded1.add(totalAdded2).lte(tapFinalSupply.sub(tapInitialSupply)), `total added`).to.be.true;
    });
});
