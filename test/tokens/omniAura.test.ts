import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { LZEndpointMock, OmniAura, AuraIntegrator, ERC20Mock, AuraLockerMock } from '../../typechain';

import { deployLZEndpointMock, BN, deployOmniAura, deployAuraIntegrator, time_travel } from '../test.utils';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('omniAura', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let signer3: SignerWithAddress;
    let auraToken: ERC20Mock;
    let erc20Mock: ERC20Mock;

    let LZEndpointMock0: LZEndpointMock;
    let auraIntegrator: AuraIntegrator;
    let oAura: OmniAura;

    let auraLockerMock: AuraLockerMock;

    async function register() {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        signer3 = (await ethers.getSigners())[2];

        auraToken = (await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9))) as ERC20Mock; //aura

        erc20Mock = (await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9))) as ERC20Mock; //reward token
        auraLockerMock = (await (
            await hre.ethers.getContractFactory('AuraLockerMock')
        ).deploy('test', 't', auraToken.address, erc20Mock.address, erc20Mock.address)) as AuraLockerMock; //aura

        auraIntegrator = (await deployAuraIntegrator(auraLockerMock.address, signer2.address)) as AuraIntegrator; //TODO add aura locker
        LZEndpointMock0 = await deployLZEndpointMock(1);
        oAura = (await deployOmniAura(LZEndpointMock0.address, auraIntegrator.address)) as OmniAura;
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should set integrator', async () => {
        await expect(oAura.connect(signer2).setIntegrator(auraIntegrator.address)).to.be.reverted;
        await expect(oAura.connect(signer).setIntegrator(auraIntegrator.address)).to.emit(oAura, 'AuraIntegratorUpdated');
    });

    it('should not be able to deploy with an empty LayerZero endpoint', async () => {
        const factory = await ethers.getContractFactory('omniAura');
        await expect(factory.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero)).to.be.reverted;
    });

    it('should mint omniAura', async () => {
        const amount = BN(10000).mul((1e18).toString());
        await expect(oAura.connect(signer).wrap(amount)).to.be.reverted;

        const auraTokenDecimals = await auraToken.decimals();
        const oAuraTokenDecimals = await oAura.decimals();
        expect(auraTokenDecimals == oAuraTokenDecimals).to.be.true;

        await auraToken.freeMint(amount);
        await auraToken.approve(oAura.address, amount);

        await expect(oAura.connect(signer).wrap(amount)).to.emit(oAura, 'Minted').withArgs(signer.address, signer.address, amount, true);
        let oAuraSignerBalance = await oAura.balanceOf(signer.address);
        expect(oAuraSignerBalance.eq(amount)).to.be.true;

        // function lockedBalances(address _user)
        let totalLocked = (await auraLockerMock.lockedBalances(auraIntegrator.address))[0];
        expect(totalLocked.eq(amount)).to.be.true;

        await auraToken.connect(signer2).freeMint(amount);
        await auraToken.connect(signer2).approve(oAura.address, amount);
        await expect(oAura.connect(signer2).wrapFor(amount, signer.address))
            .to.emit(oAura, 'Minted')
            .withArgs(signer2.address, signer.address, amount, true);
        oAuraSignerBalance = await oAura.balanceOf(signer.address);
        expect(oAuraSignerBalance.eq(amount.mul(2))).to.be.true;

        totalLocked = (await auraLockerMock.lockedBalances(auraIntegrator.address))[0];
        expect(totalLocked.eq(amount.mul(2))).to.be.true;
    });

    it('should set integrator', async () => {
        await expect(auraIntegrator.connect(signer2).setAuraLocker(auraLockerMock.address)).to.be.reverted;
        await expect(auraIntegrator.connect(signer).setAuraLocker(auraLockerMock.address))
            .to.emit(auraIntegrator, 'AuraLockerUpdated')
            .withArgs(auraLockerMock.address, auraLockerMock.address);
    });

    it('should process locked', async () => {
        await expect(auraIntegrator.triggerProcessLocked()).to.be.revertedWith('no locks');
        await expect(auraIntegrator.triggerLock()).to.be.revertedWith('AI: nothing to lock');

        const amount = BN(10000).mul((1e18).toString());
        await auraToken.freeMint(amount);
        await auraToken.transfer(auraIntegrator.address, amount);

        await expect(auraIntegrator.triggerLock()).not.to.be.reverted;
        await expect(auraIntegrator.triggerProcessLocked()).to.be.revertedWith('no exp locks');
        let totalLocked = (await auraLockerMock.lockedBalances(auraIntegrator.address))[0];
        expect(totalLocked.eq(amount)).to.be.true;

        time_travel(7 * 86400 * 50); //locks should have expired
        await auraLockerMock.checkpointEpoch();
        const unlockable = (await auraLockerMock.lockedBalances(auraIntegrator.address))[1];
        expect(unlockable.eq(amount)).to.be.true;
        await expect(auraIntegrator.triggerProcessLocked()).not.to.be.reverted;
        totalLocked = (await auraLockerMock.lockedBalances(auraIntegrator.address))[0];
        expect(totalLocked.eq(amount)).to.be.true;
    });

    it('should trigger delegate', async () => {
        const amount = BN(10000).mul((1e18).toString());
        await auraToken.freeMint(amount);
        await auraToken.transfer(auraIntegrator.address, amount);
        await expect(auraIntegrator.triggerLock()).not.to.be.reverted;

        await expect(auraIntegrator.triggerDelegate()).to.not.be.reverted;
        let delegatee = await auraLockerMock.delegates(auraIntegrator.address);
        expect(delegatee.toLowerCase()).to.eq(signer2.address.toLowerCase());

        await expect(auraIntegrator.connect(signer2).setDelegatee(signer3.address)).to.be.reverted;
        await expect(auraIntegrator.setDelegatee(signer3.address)).to.emit(auraIntegrator, 'DelegateeUpdated');
        await expect(auraIntegrator.triggerDelegate()).to.not.be.reverted;
        delegatee = await auraLockerMock.delegates(auraIntegrator.address);
        expect(delegatee.toLowerCase()).to.eq(signer3.address.toLowerCase());
    });

    it('should execute generic method on AuraLocker contract', async () => {
        // await auraLockerMock.checkpointEpoch();

        const amount = BN(10000).mul((1e18).toString());
        await auraToken.freeMint(amount);
        await auraToken.transfer(auraIntegrator.address, amount);

        await expect(auraIntegrator.triggerLock()).not.to.be.reverted;
        await expect(auraIntegrator.triggerProcessLocked()).to.be.revertedWith('no exp locks');
        let totalLocked = (await auraLockerMock.lockedBalances(auraIntegrator.address))[0];
        expect(totalLocked.eq(amount)).to.be.true;

        time_travel(7 * 86400 * 50); //locks should have expired

        const checkpointFn = auraLockerMock.interface.encodeFunctionData('checkpointEpoch', []);
        await expect(auraIntegrator.executeAuraLockerFn(checkpointFn)).to.not.be.reverted;
        const unlockable = (await auraLockerMock.lockedBalances(auraIntegrator.address))[1];
        expect(unlockable.eq(amount)).to.be.true;
    });
});
