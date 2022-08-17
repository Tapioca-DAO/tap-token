import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock, LZEndpointMock, Minter, TapOFT, VeTap, GaugeController } from '../../typechain';

import {
    deployLZEndpointMock,
    deployTapiocaOFT,
    deployveTapiocaNFT,
    BN,
    time_travel,
    deployGaugeController,
    deployMinter,
} from '../test.utils';
import { BigNumber } from 'ethers';

describe('minter', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let mockedLiquidityGauge: any;
    let LZEndpointMock: LZEndpointMock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let gaugeController: GaugeController;
    let minter: Minter;
    const DAY: number = 86400;

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        const latestBlock = await ethers.provider.getBlock('latest');

        LZEndpointMock = (await deployLZEndpointMock(0)) as LZEndpointMock;
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, 'veTapioca Token', 'veTAP', '1')) as VeTap;
        gaugeController = (await deployGaugeController(tapiocaOFT.address, veTapioca.address)) as GaugeController;
        minter = (await deployMinter(tapiocaOFT.address, gaugeController.address)) as Minter;

        const mockedLiquidityGaugeFactory = await ethers.getContractFactory('LiquidityMockGauge');
        mockedLiquidityGauge = await mockedLiquidityGaugeFactory.connect(signer).deploy();
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should check initial state', async () => {
        const savedAdmin = await minter.admin();
        expect(savedAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        const savedToken = await minter.token();
        expect(savedToken.toLowerCase()).to.eq(tapiocaOFT.address.toLowerCase());

        const savedController = await minter.controller();
        expect(savedController.toLowerCase()).to.eq(gaugeController.address.toLowerCase());
    });

    it('should change admin', async () => {
        const savedAdmin = await minter.admin();
        expect(savedAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        const savedFutureAdmin = await gaugeController.future_admin();
        expect(savedFutureAdmin.toLowerCase()).to.eq(ethers.constants.AddressZero.toLowerCase());
        await gaugeController.commit_transfer_ownership(signer2.address);

        const newFutureAdmin = await gaugeController.future_admin();
        expect(newFutureAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());

        const stillTheSameAdmin = await gaugeController.admin();
        expect(stillTheSameAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        await gaugeController.apply_transfer_ownership();

        const finalAdmin = await gaugeController.admin();
        expect(finalAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());
    });

    it('should toggle approve mint', async () => {
        const initialStatus = await minter.allowed_to_mint_for(signer2.address, signer.address);
        expect(initialStatus).to.be.false;

        await minter.connect(signer).toggle_approve_mint(signer2.address);

        const finalStatus = await minter.allowed_to_mint_for(signer2.address, signer.address);
        expect(finalStatus).to.be.true;
    });

    it('should mint', async () => {
        await expect(minter.connect(signer2).mint(mockedLiquidityGauge.address)).to.be.reverted;

        await gaugeController.add_type('Test', 0);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, 0);

        await tapiocaOFT.setMinter(minter.address);

        const signer2TapBalance = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalance.eq(0)).to.be.true;

        const shouldMint = await mockedLiquidityGauge.test();

        time_travel(250 * DAY);
        // await tapiocaOFT.updateMiningParameters();
        await minter.connect(signer2).mint(mockedLiquidityGauge.address);

        const signer2FinalTapBalance = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2FinalTapBalance.gt(signer2TapBalance)).to.be.true;
        expect(signer2FinalTapBalance.eq(shouldMint)).to.be.true;
    });

    it('should mint for', async () => {
        await gaugeController.add_type('Test', 0);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, 0);
        await tapiocaOFT.setMinter(minter.address);

        const signer2TapBalance = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalance.eq(0)).to.be.true;

        time_travel(250 * DAY);

        // await tapiocaOFT.updateMiningParameters();
        await minter.connect(signer).mint_for(mockedLiquidityGauge.address, signer2.address);
        const signer2TapBalanceAfterFirstMint = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceAfterFirstMint.eq(0)).to.be.true; //should mint nothing as there is no approval for it yet

        await minter.connect(signer2).toggle_approve_mint(signer.address);

        const shouldMint = await mockedLiquidityGauge.test();
        await minter.connect(signer).mint_for(mockedLiquidityGauge.address, signer2.address);

        const signer2TapBalanceAfterFinalMint = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalanceAfterFinalMint.gt(signer2TapBalance)).to.be.true;

        expect(signer2TapBalanceAfterFinalMint.eq(shouldMint)).to.be.true;
    });

    it('should mint many', async () => {
        await gaugeController.add_type('Test', 0);
        await gaugeController.add_gauge(mockedLiquidityGauge.address, 0, 0);
        await tapiocaOFT.setMinter(minter.address);

        //Second gauge - needs deployment
        const mockedLiquidityGaugeFactory = await ethers.getContractFactory('LiquidityMockGauge');
        const anotherLiquidityGauge = await mockedLiquidityGaugeFactory.connect(signer).deploy();

        await gaugeController.add_gauge(anotherLiquidityGauge.address, 0, 0);

        const shouldMintFirstGauge = await mockedLiquidityGauge.test();
        const shouldMintSecondGauge = await anotherLiquidityGauge.test();

        time_travel(550 * DAY);
        // await tapiocaOFT.updateMiningParameters();

        await minter
            .connect(signer2)
            .mint_many([
                mockedLiquidityGauge.address,
                anotherLiquidityGauge.address,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
            ]);

        const signer2TapBalance = await tapiocaOFT.balanceOf(signer2.address);
        expect(signer2TapBalance.eq(shouldMintFirstGauge.add(shouldMintSecondGauge))).to.be.true;
    });
});
