import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { exportSDK__task } from './tasks/exportSDK';
import { setTrustedRemote__task } from './tasks/setTrustedRemote';
import { deployERC20Mock__task, deployOracleMock__task, deployVesting__task } from './tasks/contractDeployment';
import {
    setOracleMockRate__task,
    setTOBPaymentToken__task,
    setTOLPRegisterSingularity__task,
    setTOLPUnregisterSingularity__task,
    setYieldBoxRegisterAsset__task,
} from './tasks/setterTasks';
import { getLocalDeployments__task, getSDKDeployments__task } from './tasks/getDeployments';
import { configurePacketTypes__task } from './tasks/configurePacketTypes';
import { glob } from 'typechain';

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task('exportSDK', 'Generate and export the typings and/or addresses for the SDK. May deploy contracts.', exportSDK__task).addFlag(
    'mainnet',
    'Using the current chain ID deployments.',
);

task('getLocalDeployment', 'Try to load a local deployment.', getLocalDeployments__task).addOptionalParam(
    'contractName',
    'The name of the contract to load',
);

task('getContractNames', 'Get the names of all contracts deployed on the current chain ID.', async (taskArgs, hre) => {
    console.log(glob(process.cwd(), [`${hre.config.paths.artifacts}/**/!(*.dbg).json`]).map((e) => e.split('/').slice(-1)[0]));
});

task('getSDKDeployment', 'Try to load an SDK deployment.', getSDKDeployments__task)
    .addParam('repo', 'The name of the repo to load the deployment from')
    .addOptionalParam('contractName', 'The name of the contract to load');

task('setTrustedRemote', 'Calls setTrustedRemote on TapOFT contract', setTrustedRemote__task)
    .addParam('chain', 'LZ destination chain id for trusted remotes')
    .addParam('dst', 'TapOFT destination address')
    .addParam('src', 'TapOFT source address');

task('deployVesting', 'Deploys a new Vesting contract', deployVesting__task)
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('token', 'Vested token')
    .addParam('cliff', 'Cliff duration in seconds')
    .addParam('duration', 'Vesting duration in seconds');

task('deployERC20Mock', 'Deploys a new ERC20 Mock contract', deployERC20Mock__task)
    .addParam('deploymentName', 'Name of the deployment')
    .addParam('name', 'Name of the token')
    .addParam('symbol', 'Symbol of the token')
    .addParam('initialAmount', 'Initial amount of tokens')
    .addParam('decimals', 'Number of decimals');

task('deployOracleMock', 'Deploys a new Oracle mock contract', deployOracleMock__task)
    .addParam('deploymentName', 'The name of the deployment')
    .addParam('erc20Name', 'Initial amount of tokens');

task('setOracleMockRate', 'Set exchange rate for a mock oracle', setOracleMockRate__task)
    .addParam('oracleAddress', 'Address of the oracle')
    .addParam('rate', 'Exchange rate');

task('setTOBPaymentToken', 'Set a payment token on tOB', setTOBPaymentToken__task)
    .addParam('tknAddress', 'Address of the payment token')
    .addParam('oracleAddress', 'Address of the oracle')
    .addParam('oracleData', 'Oracle data');

task('setTOLPRegisterSingularity', 'Register an SGL on tOLP ', setTOLPRegisterSingularity__task)
    .addParam('sglAddress', 'Address of the SGL receipt token')
    .addParam('assetId', 'YieldBox asset ID of the SGL receipt token')
    .addParam('weight', 'Weight of the gauge');

task('setTOLPUnregisterSingularity', 'Unregister an SGL on tOLP ', setTOLPUnregisterSingularity__task).addParam(
    'sglAddress',
    'Address of the SGL receipt token',
);

task('setYieldBoxRegisterAsset', 'Register an SGL on tOLP ', setYieldBoxRegisterAsset__task)
    .addParam('tknAddress', 'Address of the SGL receipt token')
    .addOptionalParam('tknType', 'YieldBox type of the token. 0 for natives, 1 for ERC20, 2 for ERC721, 3 for ERC1155, 4 for none')
    .addOptionalParam('tknId', 'ID of the token, 0 if ERC20, others if ERC721')
    .addOptionalParam('strategy', 'Address of the strategy contract')
    .addOptionalParam('strategyName', 'Name of the strategy contract')
    .addOptionalParam('strategyDesc', 'Description of the strategy contract');
task('configurePacketTypes', 'Cofigures min destination gas and the usage of custom adapters', configurePacketTypes__task)
    .addParam('dstLzChainId', 'LZ destination chain id for trusted remotes')
    .addParam('src', 'TAP address');
