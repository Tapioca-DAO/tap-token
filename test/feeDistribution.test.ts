import hh, { ethers } from 'hardhat';
import { expect } from 'chai';
import { FeeDistributor, Minter, Tap, VeTap } from '../typechain';

const nWeeks = (n: number) => Math.floor(Date.now() / 1000) + n * 7 * 86400;

describe('veTAP', async () => {
    let tap: Tap;
    let veTap: VeTap;
    let feeDistributor: FeeDistributor;
    let minter: Minter;

    const TEAM_WALLET = new ethers.Wallet(ethers.Wallet.createRandom().privateKey, ethers.provider);

    before(async () => {
        minter = await ethers.getContractAt('Minter', (await (await ethers.getContractFactory('Minter')).deploy()).address);

        tap = await (
            await ethers.getContractFactory('Tap')
        ).deploy(
            TEAM_WALLET.address,
            ethers.constants.AddressZero,
            minter.address,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
        );
        await tap.deployed();
        veTap = await (await ethers.getContractFactory('VeTap')).deploy(tap.address, 'veTAP', 'veTAP', '1');
        await veTap.deployed();

        feeDistributor = await ethers.getContractAt(
            'FeeDistributor',
            (
                await (
                    await ethers.getContractFactory('FeeDistributor')
                ).deploy(
                    veTap.address,
                    await (
                        await ethers.provider.getBlock('latest')
                    ).timestamp,
                    tap.address,
                    TEAM_WALLET.address,
                    TEAM_WALLET.address,
                )
            ).address,
        );

        await minter.init(tap.address, veTap.address, feeDistributor.address);

        await (await ethers.getSigners())[0].sendTransaction({ to: TEAM_WALLET.address, value: ethers.utils.parseEther('1') });
    });

    it('should pass', async () => {
        expect(await minter.getEmission()).to.eq(0);

        await tap.connect(TEAM_WALLET).approve(veTap.address, ethers.BigNumber.from(10_000_000).mul((1e18).toString()));
        await veTap.connect(TEAM_WALLET).create_lock(ethers.BigNumber.from(10_000_000).mul((1e18).toString()), nWeeks(4));

        console.log(Number((await minter.getEmission()).toString()) / 1e18);
        console.log(Number((await minter.getMintable()).toString()) / 1e18);
    });
});
