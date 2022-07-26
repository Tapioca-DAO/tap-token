import hh, { ethers } from 'hardhat';
import { expect } from 'chai';
import { Tap, VeTap } from '../typechain';

const nWeeks = (n: number) => Math.floor(Date.now() / 1000) + n * 7 * 86400;

describe('veTAP', () => {
    let tap: Tap;
    let veTap: VeTap;

    const TEAM_WALLET = new ethers.Wallet(ethers.Wallet.createRandom().privateKey, ethers.provider);
    const DUMMY_WALLET = new ethers.Wallet(ethers.Wallet.createRandom().privateKey, ethers.provider);

    before(async () => {
        tap = await (
            await ethers.getContractFactory('Tap')
        ).deploy(
            TEAM_WALLET.address,
            DUMMY_WALLET.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
        );
        await tap.deployed();
        veTap = await (await ethers.getContractFactory('VeTap')).deploy(tap.address, 'veTAP', 'veTAP', '1');
        await veTap.deployed();

        await (await ethers.getSigners())[0].sendTransaction({ to: TEAM_WALLET.address, value: ethers.utils.parseEther('1') });
        await (await ethers.getSigners())[0].sendTransaction({ to: DUMMY_WALLET.address, value: ethers.utils.parseEther('1') });
    });

    it('should pass', async () => {
        await tap.connect(TEAM_WALLET).approve(veTap.address, (1e18).toString());
        await tap.connect(DUMMY_WALLET).transfer(veTap.address, (1e18).toString());

        await veTap.connect(TEAM_WALLET).create_lock((1e18).toString(), nWeeks(1));

        await hh.network.provider.send('evm_increaseTime', [nWeeks(2)]);
        await hh.network.provider.send('evm_mine');
    });
});
