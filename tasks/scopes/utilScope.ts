import '@nomiclabs/hardhat-ethers';
import { glob } from 'glob';
import { scope } from 'hardhat/config';

const utilScope = scope('utils', 'Utility tasks');

utilScope.task(
    'accounts',
    'Prints the list of accounts',
    async (taskArgs, hre) => {
        const accounts = await hre.ethers.getSigners();

        for (const account of accounts) {
            console.log(account.address);
        }
    },
);

utilScope.task(
    'getContractNames',
    'Get the names of all contracts deployed on the current chain ID.',
    async (taskArgs, hre) => {
        console.log(
            (
                await glob([`${hre.config.paths.artifacts}/**/!(*.dbg).json`])
            ).map((e) => e.split('/').slice(-1)[0]),
        );
    },
);
utilScope
    .task(
        'balanceOf',
        'Get the balance of an account. Default is signer.',
        async (taskArgs: { account?: string }, hre) => {
            const accounts = await hre.ethers.getSigners();
            const signer = accounts[0];
            const balance = taskArgs.account
                ? await hre.ethers.provider.getBalance(taskArgs.account)
                : await signer.getBalance();
            console.log(hre.ethers.utils.formatEther(balance), 'ETH');
        },
    )
    .addOptionalParam('account', 'The account to check the balance of.');

utilScope.task(
    'currentAccount',
    'Get the address of the loaded private key.',
    async (taskArgs: { account?: string }, hre) => {
        const accounts = await hre.ethers.getSigners();
        const signer = accounts[0];
        console.log(signer.address);
    },
);
