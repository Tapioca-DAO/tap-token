import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';

export const adb_addPaymentToken__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & {
        paymentToken: string;
        oracle: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        // eslint-disable-next-line @typescript-eslint/no-empty-function
        async () => {},
        tapiocaTask,
    );
};

async function tapiocaTask(
    params: TTapiocaDeployerVmPass<{
        paymentToken: string;
        oracle: string;
    }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, oracle, paymentToken } = taskArgs;

    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.AIRDROP_BROKER,
            tag,
        ).address,
    );

    const oracleContract = await hre.ethers.getContractAt(
        'ITapiocaOracle',
        oracle,
    );

    // await adb.setPaymentToken(paymentToken, oracle, '0x');
    await VM.executeMulticall([
        {
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setPaymentToken', [
                paymentToken,
                oracle,
                '0x',
            ]),
        },
    ]);
    console.log(
        `[+] Payment token set to ${paymentToken}, oracle set to ${oracle}, data set to 0x in ADB contract`,
    );
    console.log(
        '[+] Oracle rate',
        hre.ethers.utils.formatEther((await oracleContract.peek('0x')).rate),
    );
}
