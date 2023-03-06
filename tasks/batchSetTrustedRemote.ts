import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';

// npx hardhat batchSetTrustedRemote --network arbitrum_goerli --contract 'MarketsProxy'
export const batchSetTrustedRemote__task = async (taskArgs: { contract: string }, hre: HardhatRuntimeEnvironment) => {
    console.log('\nRetrieving necessary data');
    const currentChainId = await hre.getChainId();

    const oftFactory = await hre.ethers.getContractFactory(taskArgs.contract);
    const deployments = SDK.API.utils.readDeployments();
    const oftEntriesData = SDK.API.utils.getTapiocaOftEnties(deployments, taskArgs.contract, oftFactory);
    const chainTransactions = oftEntriesData.filter((a: { srChain: string }) => a.srChain == currentChainId);

    console.log(`\nTotal transactions: ${chainTransactions.length}`);
    let sum = 0;
    for (let i = 0; i < chainTransactions.length; i++) {
        const crtTx = chainTransactions[i];
        const ctr = await hre.ethers.getContractAt(taskArgs.contract, crtTx.srcAddress);
        await (await ctr.setTrustedRemote(crtTx.dstLzChain, crtTx.trustedRemotePath)).wait(2);
        console.log(`       * executed ${i}`);
        sum += 1;
    }
    console.log(`Done. Executed ${sum} transactions`);
};
