import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { SendParamStruct } from '@typechain/contracts/tokens/BaseTapToken';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import { Options } from '@layerzerolabs/lz-v2-utilities';
import { ERC20Mock, TapToken } from '@typechain/index';
import { Contract } from 'ethers';

export const exec__sendToken__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & {
        targetNetwork: string;
        targetAddress: string;
        amount: string;
        isMulticall: boolean;
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
        targetNetwork: string;
        targetAddress: string;
        amount: string;
        isMulticall: boolean;
    }>,
) {
    // Settings
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, targetNetwork, amount, isMulticall, targetAddress } = taskArgs;
    const targetChain = hre.SDK.utils.getChainBy('name', targetNetwork);

    const localContract = (await hre.ethers.getContractAt(
        'tap-token/tokens/TapToken.sol:TapToken',
        loadLocalContract(
            hre,
            chainInfo.chainId,
            DEPLOYMENT_NAMES.TAP_TOKEN,
            tag,
        ).address,
    )) as TapToken;

    const amountLD = hre.ethers.utils.parseEther(amount);

    const sendData: SendParamStruct = {
        amountLD,
        minAmountLD: amountLD,
        to: '0x'.concat(targetAddress.split('0x')[1].padStart(64, '0')),
        dstEid: targetChain.lzChainId,
        extraOptions: Options.newOptions()
            .addExecutorLzReceiveOption(1_000_000)
            .toHex(),
        composeMsg: '0x',
        oftCmd: '0x',
    };

    const quoteSend = await localContract.callStatic.quoteSend(sendData, false);
    console.log('[+] Sending', 1, 'TAP');
    console.log(
        '[+] Quote for sending TAP:',
        hre.ethers.utils.formatUnits(quoteSend.nativeFee, 'ether'),
    );
    console.log('[+] To address', targetAddress);

    if (isMulticall) {
        console.log('[+] Sending TAP using multicall');
        const multicall = await VM.getMulticall();
        const tx = await multicall.multicallValue(
            [
                {
                    target: localContract.address,
                    allowFailure: false,
                    callData: localContract.interface.encodeFunctionData(
                        'send',
                        [
                            sendData,
                            {
                                lzTokenFee: 0,
                                nativeFee: quoteSend.nativeFee,
                            },
                            multicall.address,
                        ],
                    ),
                    value: quoteSend.nativeFee,
                },
            ],
            { gasLimit: 10_000_000, value: quoteSend.nativeFee },
        );
        console.log('[+] Tx sent: ', tx.hash);
    } else {
        console.log('[+] Sending TAP using direct call');
        const signer = hre.ethers.provider.getSigner();
        const tx = await (
            await localContract.send(
                sendData,
                {
                    lzTokenFee: 0,
                    nativeFee: quoteSend.nativeFee,
                },
                await signer.getAddress(),
            )
        ).wait(3);
        console.log('[+] Tx sent: ', tx.transactionHash);
    }
}
