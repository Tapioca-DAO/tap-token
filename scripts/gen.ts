import { Wallet } from 'ethers';
import fs from 'fs';
import hre from 'hardhat';
import MerkleTree from 'merkletreejs';

const randomSigners = async (amount: number) => {
    const signers: { address: string; pk: string }[] = [];
    for (let i = 0; i < amount; i++) {
        const signer = hre.ethers.Wallet.createRandom();
        signers.push({
            address: signer.address,
            pk: signer.privateKey,
        });
    }
    return {
        signers,
    };
};

// Using https://docs.tapioca.xyz/tapioca/launch/option-airdrop#phase-two-core-tapioca-guild numbers
const main = async () => {
    const data = [
        {
            role: 0, // OG Pearls
            ...(await randomSigners(45)),
        },
        {
            role: 1, // Sushi Frens
            ...(await randomSigners(365)),
        },
        {
            role: 2, // Tapiocans
            ...(await randomSigners(416)),
        },
        {
            role: 3, // Oysters
            ...(await randomSigners(1870)),
        },
    ];
    fs.writeFileSync('./output.json', JSON.stringify(data, null, 2));
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log(error);
    });
