import hre, { ethers } from 'hardhat';

export const setupTwTAPFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];
    const users = (await hre.ethers.getSigners()).splice(1);

    // Tap OFT
    const tapOFT = await (
        await ethers.getContractFactory('ERC20Mock')
    ).deploy('TapOFT', 'TapOFT', (1e18).toString(), 18, signer.address);

    // twtap
    const twtap = await (
        await ethers.getContractFactory('TwTAP')
    ).deploy(tapOFT.address, signer.address);

    return {
        // signers
        signer,
        users,
        // vars
        tapOFT,
        twtap,
    };
};
