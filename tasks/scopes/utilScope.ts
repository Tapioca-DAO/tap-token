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
