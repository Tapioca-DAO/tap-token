import hre from 'hardhat';

async function main() {
    const { deployments } = hre;
    const all = await deployments.all();
    Object.keys(all).map(async (e) => {
        console.log({ [e]: all[e].address });
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
