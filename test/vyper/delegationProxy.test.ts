import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock, LZEndpointMock, TapOFT } from '../../typechain/';
import { VeTap } from '../../typechain/contracts/vyper/VeTap.vy';
import { BoostV2 } from '../../typechain/contracts/vyper/BoostV2.vy';
import { DelegationProxy } from '../../typechain/contracts/vyper/DelegationProxy.vy';

import { deployLZEndpointMock, deployTapiocaOFT, deployveTapiocaNFT, deployBoostV2, BN } from '../test.utils';

import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('delegation proxy', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let LZEndpointMock: LZEndpointMock;
    let erc20Mock: ERC20Mock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let boostV2: BoostV2;
    let delegationProxy: DelegationProxy;

    const veTapiocaName = 'veTapioca Token';
    const veTapiocaSymbol = 'veTAP';
    const veTapiocaVersion = '1';
    const DAY: number = 86400;
    const HALF_UNLOCK_TIME: number = 2 * 365 * DAY; //half of max time
    const UNLOCK_TIME: number = 2 * HALF_UNLOCK_TIME; //max time

    async function register() {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        const chainId = (await ethers.provider.getNetwork()).chainId;
        LZEndpointMock = (await deployLZEndpointMock(chainId)) as LZEndpointMock;
        erc20Mock = (await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9))) as ERC20Mock;
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, veTapiocaName, veTapiocaSymbol, veTapiocaVersion)) as VeTap;
        boostV2 = (await deployBoostV2(veTapioca.address)) as BoostV2;
        delegationProxy = (await (
            await hre.ethers.getContractFactory('DelegationProxy')
        ).deploy(boostV2.address, signer.address, signer.address)) as DelegationProxy;
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should delegate', async () => {
        const amount = BN(1000).mul((1e18).toString());
        const boostV2Interface = await ethers.getContractAt('IBoostV2', boostV2.address);

        await expect(boostV2Interface.boost(signer.address, 0, 0, signer.address)).to.be.revertedWith('receiver not valid');
        await expect(boostV2Interface.boost(signer2.address, 0, 0, signer.address)).to.be.revertedWith('amount not valid');
        await expect(boostV2Interface.boost(signer2.address, amount, 0, signer.address)).to.be.revertedWith('min time');

        const latestBlock = await ethers.provider.getBlock('latest');
        await expect(boostV2Interface.boost(signer2.address, amount, 2056320001, signer.address)).to.be.revertedWith('time not valid');
        await expect(boostV2Interface.boost(signer2.address, amount, 2056320000 * 100, signer.address)).to.be.revertedWith('max time');

        const amountToLock = BN(10000).mul((1e18).toString());
        const minLockedAmount = BN(9000).mul((1e18).toString());

        await tapiocaOFT.connect(signer).approve(veTapioca.address, amountToLock);
        await veTapioca.connect(signer).create_lock(amountToLock, latestBlock.timestamp + UNLOCK_TIME);

        const erc20 = await ethers.getContractAt('IOFT', veTapioca.address);

        const signerVotingBalance = await delegationProxy.adjusted_balance_of(signer.address);
        const signerVotingBalanceBeforeFromVe = await erc20.balanceOf(signer.address);
        expect(signerVotingBalanceBeforeFromVe.eq(signerVotingBalance)).to.be.true;
        expect(signerVotingBalance.gt(minLockedAmount)).to.be.true;

        const delegable = await boostV2.delegable_balance(signer.address);
        expect(delegable.gt(0)).to.be.true;

        const week = 86400 * 7;
        const dividable = parseInt((latestBlock.timestamp / week).toString());
        const boostTime = (dividable + 10) * week;
        await expect(delegationProxy.set_delegation(boostV2.address)).to.emit(delegationProxy, 'DelegationSet');
        await expect(boostV2Interface.boost(signer2.address, amount, boostTime, signer.address)).to.not.be.reverted;

        const signerVotingBalanceAfterFromVe = await erc20.balanceOf(signer.address);
        const balance = await delegationProxy.adjusted_balance_of(signer2.address);
        expect(balance.gt(0)).to.be.true;
        expect(balance.lte(signerVotingBalance)).to.be.true;
        expect(signerVotingBalanceAfterFromVe.lte(signerVotingBalanceBeforeFromVe)).to.be.true; //should have not decrease the original veBalance of signer
        expect(signerVotingBalanceAfterFromVe.sub(signerVotingBalanceBeforeFromVe).lt(BN(100).mul((1e18).toString()))).to.be.true;
    });
});
