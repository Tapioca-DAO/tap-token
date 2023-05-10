import hre, { ethers } from 'hardhat';

export const setupTDPFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];
    const users = (await hre.ethers.getSigners()).splice(1);

    // Tap OFT
    const tapOFT = await (
        await ethers.getContractFactory('ERC20Mock')
    ).deploy('TapOFT', 'TapOFT', (1e18).toString(), 18, signer.address);

    // twTAP / DAO Portal
    const tDP = await (
        await ethers.getContractFactory('TapiocaDAOPortal')
    ).deploy(tapOFT.address, signer.address);

    return {
        // signers
        signer,
        users,
        // vars
        tapOFT,
        tDP,
    };
};
