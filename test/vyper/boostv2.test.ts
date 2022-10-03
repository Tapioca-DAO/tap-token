import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock, LZEndpointMock, TapOFT } from '../../typechain/';
import { VeTap } from '../../typechain/contracts/vyper/VeTap.vy';
import { BoostV2 } from '../../typechain/contracts/vyper/BoostV2.vy';

import { deployLZEndpointMock, deployTapiocaOFT, deployveTapiocaNFT, deployBoostV2, BN } from '../test.utils';

import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('boost v2', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let LZEndpointMock: LZEndpointMock;
    let erc20Mock: ERC20Mock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let boostV2: BoostV2;

    const veTapiocaName = 'veTapioca Token';
    const veTapiocaSymbol = 'veTAP';
    const veTapiocaVersion = '1';
    const DAY: number = 86400;
    const HALF_UNLOCK_TIME: number = 1 * 365 * DAY; //half of max time
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
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should check view properties', async () => {
        const domainSeparator = await boostV2.DOMAIN_SEPARATOR();
        expect(domainSeparator.length > 0).to.be.true;

        const veAddress = await boostV2.VE();
        expect(veAddress.toLowerCase()).to.eq(veTapioca.address.toLowerCase());

        const decimals = await boostV2.decimals();
        expect(decimals == 18).to.be.true;

        const savedName = await boostV2.name();
        expect(savedName).to.eq('Vote-Escrowed Boost');

        const savedSymbol = await boostV2.symbol();
        expect(savedSymbol).to.eq('veBoost');

        const delegableBalance = await boostV2.delegable_balance(signer.address);
        expect(delegableBalance.eq(0)).to.be.true;

        const receivedBalance = await boostV2.received_balance(signer.address);
        expect(receivedBalance.eq(0)).to.be.true;
    });

    it('should approve and increase allowance', async () => {
        const amount = BN(1000).mul((1e18).toString());

        let currentAllowance = await boostV2.allowance(signer.address, signer2.address);
        expect(currentAllowance.eq(0)).to.be.true;

        await expect(boostV2.approve(signer2.address, amount)).to.not.be.reverted;
        currentAllowance = await boostV2.allowance(signer.address, signer2.address);
        expect(currentAllowance.eq(amount)).to.be.true;

        await expect(boostV2.increaseAllowance(signer2.address, amount)).to.not.be.reverted;
        currentAllowance = await boostV2.allowance(signer.address, signer2.address);
        expect(currentAllowance.eq(amount.mul(2))).to.be.true;

        await expect(boostV2.decreaseAllowance(signer2.address, amount)).to.not.be.reverted;
        currentAllowance = await boostV2.allowance(signer.address, signer2.address);
        expect(currentAllowance.eq(amount)).to.be.true;
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

        const erc20 = await ethers.getContractAt('ERC20Mock', veTapioca.address);

        const signerVotingBalance = await erc20.balanceOf(signer.address);
        expect(signerVotingBalance.gt(minLockedAmount)).to.be.true;

        const delegable = await boostV2.delegable_balance(signer.address);
        expect(delegable.gt(0)).to.be.true;

        const week = 86400 * 7;
        const dividable = parseInt((latestBlock.timestamp / week).toString());
        const boostTime = (dividable + 1) * week;
        await expect(boostV2Interface.boost(signer2.address, amount, boostTime, signer.address)).to.not.be.reverted;

        const delegatedBySigner = await boostV2.delegated(signer.address);
        expect(delegatedBySigner[0].gt(0)).to.be.true;

        const receivedBalance = await boostV2.received_balance(signer2.address);
        expect(receivedBalance.gt(0)).to.be.true;

        expect(receivedBalance.eq(delegatedBySigner[0])).to.be.true;
    });
});
