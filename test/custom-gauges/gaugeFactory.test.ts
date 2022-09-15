import { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import { LZEndpointMock, TapOFT, TimedGauge, ERC20Mock, GaugeFactory, GaugeDistributor } from '../../typechain/';
import { GaugeController } from '../../typechain/contracts/vyper/GaugeController.vy';
import { VeTap } from '../../typechain/contracts/vyper/VeTap.vy';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

import {
    deployLZEndpointMock,
    deployTapiocaOFT,
    deployTimedGauge,
    deployGaugeFactory,
    deployveTapiocaNFT,
    deployGaugeController,
    deployGaugeDistributor,
} from '../test.utils';

describe('GaugeFactory', () => {
    let signer: SignerWithAddress;
    let user: SignerWithAddress;
    let tapToken: TapOFT;
    let gauge: TimedGauge;
    let erc20Mock: ERC20Mock;
    let erc20Mock2: ERC20Mock;
    let gaugeDistributor: GaugeDistributor;
    let veTapioca: VeTap;
    let gaugeController: GaugeController;
    let LZEndpointMock: LZEndpointMock;
    let gaugeFactory: GaugeFactory;

    async function register() {
        signer = (await ethers.getSigners())[0];
        user = (await ethers.getSigners())[1];
        const chainId = (await ethers.provider.getNetwork()).chainId;
        LZEndpointMock = (await deployLZEndpointMock(chainId)) as LZEndpointMock;
        tapToken = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        erc20Mock = (await (
            await ethers.getContractFactory('ERC20Mock')
        ).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9))) as ERC20Mock;
        erc20Mock2 = (await (
            await ethers.getContractFactory('ERC20Mock')
        ).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9))) as ERC20Mock;
        veTapioca = (await deployveTapiocaNFT(tapToken.address, 'veTapioca Token', 'veTAP', '1')) as VeTap;
        gaugeController = (await deployGaugeController(tapToken.address, veTapioca.address)) as GaugeController;
        gaugeDistributor = (await deployGaugeDistributor(tapToken.address, gaugeController.address)) as GaugeDistributor;
        gauge = (await deployTimedGauge(erc20Mock.address, tapToken.address, signer.address, gaugeDistributor.address)) as TimedGauge;
        gaugeFactory = (await deployGaugeFactory(gauge.address)) as GaugeFactory;

        await tapToken.setMinter(gaugeDistributor.address);
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should check initial state', async () => {
        const referenceAddress = await gaugeFactory.gaugeReference();
        expect(referenceAddress.toLowerCase()).to.eq(gauge.address.toLowerCase());
    });

    it('should not be able to create the factory without a reference', async () => {
        const factory = await ethers.getContractFactory('GaugeFactory');
        await expect(factory.deploy(ethers.constants.AddressZero)).to.be.revertedWith('gauge not valid');
    });

    it('should create a gauge', async () => {
        const createGaugeTx = await gaugeFactory.connect(user).createGauge(erc20Mock.address, tapToken.address, gaugeDistributor.address);
        const createGaugeRc = await createGaugeTx.wait();

        const createdGauge = createGaugeRc.events!.filter((a: any) => a.event == 'GaugeCreated')[0].args![1];
        const gauge = await ethers.getContractAt('TimedGauge', createdGauge);

        const crtOwner = await gauge.owner();
        expect(crtOwner.toLowerCase()).to.eq(user.address.toLowerCase());
    });
});
