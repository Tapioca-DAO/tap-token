import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';

// npx hardhat batchConfigureAdapterParams --network arbitrum_goerli --contract 'USD0'
export const batchConfigureAdapterParams__task = async (
    taskArgs: { contract: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('\nRetrieving necessary data');
    const currentChainId = await hre.getChainId();

    const oftFactory = await hre.ethers.getContractFactory(taskArgs.contract);
    const deployments = SDK.API.utils.readDeployments();
    const oftEntriesData = SDK.API.utils.getTapiocaOftEnties(
        deployments,
        taskArgs.contract,
        oftFactory,
    );
    const chainTransactions = oftEntriesData.filter(
        (a: { srChain: string }) => a.srChain == currentChainId,
    );

    console.log(`\nTotal transaction sets: ${chainTransactions.length}`);
    let sum = 0;
    for (let i = 0; i < chainTransactions.length; i++) {
        const crtTx = chainTransactions[i];
        const ctr = await hre.ethers.getContractAt(
            taskArgs.contract,
            crtTx.srcAddress,
        );

        await (await ctr.setUseCustomAdapterParams(true)).wait(2);

        for (
            let packetIndex = 0;
            packetIndex < crtTx.packetTypesTxs.length;
            packetIndex++
        ) {
            await (
                await ctr.setMinDstGas(
                    crtTx.dstLzChain,
                    crtTx.packetTypesTxs[packetIndex],
                    200000,
                )
            ).wait(2);
        }
        console.log(`       * executed ${i}`);
        sum += 1;
    }
    console.log(`Done. Executed ${sum} transactions`);
};
