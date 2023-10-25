import hre, { ethers } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { BN, deployLZEndpointMock } from '../test.utils';
import ERC20MockArtifact from 'tapioca-sdk/dist/artifacts/tapioca-mocks/ERC20Mock.json';
import { ERC20Mock__factory } from 'tapioca-sdk/dist/typechain/tapioca-mocks';

export const setupTwTAPFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];
    const users = (await hre.ethers.getSigners()).splice(1);

    // Tap OFT
    const one = BN(1e18);
    const hundredMil = one.mul(100_000_000);
    const tapOFT = await (
        await ethers.getContractFactory('FakeTapOFT')
    ).deploy();

    await tapOFT.mint(signer.address, hundredMil);

    // Mock tokens
    const mock0 = await (
        (await ethers.getContractFactoryFromArtifact(
            ERC20MockArtifact,
        )) as ERC20Mock__factory
    ).deploy('Mock Zero', 'MOCK0', hundredMil, 18, signer.address);
    const mock1 = await (
        (await ethers.getContractFactoryFromArtifact(
            ERC20MockArtifact,
        )) as ERC20Mock__factory
    ).deploy('Mock One', 'MOCK1', hundredMil, 18, signer.address);
    const mock2 = await (
        (await ethers.getContractFactoryFromArtifact(
            ERC20MockArtifact,
        )) as ERC20Mock__factory
    ).deploy('Mock Two', 'MOCK2', hundredMil, 18, signer.address);

    // Mock token distribution
    const tokens = [mock0, mock1, mock2];
    for (const tok of tokens) {
        await tok.freeMint(one.mul(1000));
        for (const acc of users) {
            await tok.connect(acc).freeMint(one.mul(1000));
            await time.increase(86400);
        }
    }

    const tapAmount = one.mul(1000);

    // TAP distribution. (TODO: Why is the delay necessary?)
    for (const acc of users) {
        await tapOFT.connect(acc).freeMint(tapAmount);
        await time.increase(86400);
    }

    // twtap
    const twtap = await (
        await ethers.getContractFactory('TwTAP')
    ).deploy(tapOFT.address, signer.address);
    const twtapOtherChain = await (
        await ethers.getContractFactory('FakeTwTAP')
    ).deploy(tapOFT.address, signer.address);

    // Approvals and reward token setup
    for (const tok of tokens) {
        await twtap.addRewardToken(tok.address);
    }
    for (const acc of users) {
        await tapOFT.connect(acc).approve(twtap.address, tapAmount);
    }

    return {
        // signers
        signer,
        users,
        // vars
        tapOFT,
        twtap,
        twtapOtherChain,
        tokens,
    };
};
