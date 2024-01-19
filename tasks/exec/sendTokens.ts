import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TContract, TLocalDeployment } from 'tapioca-sdk/dist/shared';
import { EChainID } from '@tapioca-sdk/api/config';
import { loadVM } from '../utils';
import { IMulticall3, TapOFTV2__factory } from "@typechain";
import { Multicall3 } from '@tapioca-sdk/typechain/tapioca-periphery';
import { ethers } from 'hardhat';

export const sendTokens__task = async (
    taskArgs: {
        target: string;
        dst: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const VM = await loadVM(hre, tag);

    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        await hre.getChainId(),
    )!;
    const dstChainInfo = hre.SDK.utils.getChainBy('name', taskArgs.dst)!;
    if (!dstChainInfo) {
        throw new Error(
            `[-] Chain ${taskArgs.dst} not found. Please use Hardhat available network name.`,
        );
    }

    // Load target contract locally
    const localDeployments = hre.SDK.db.readDeployment('local', {
        tag,
    }) as TLocalDeployment;
    const localContract = localDeployments[chainInfo.chainId]?.find(
        (e) => e.name === taskArgs.target,
    );
    if (!localContract) {
        throw new Error(`[-] Contract ${taskArgs.target} not found`);
    }

    // Transfer Ownership at the beginning of the calls
    const tapOFTv2 = await hre.ethers.getContractAt(
        'TapOFTV2',
        localContract.address,
    );

    const tapOFTHelper = await hre.ethers.getContractAt(
        'TapOFTv2Helper',
        '0xD99fFcb12f9Dd2B337a27046C6F198F2deb2fAB4',
    );

    const data = await tapOFTHelper.prepareLzCall(tapOFTv2.address, {
        dstEid: dstChainInfo.lzChainId,
        lzReceiveGas: 200_000,
        lzReceiveValue: 0,
        msgType: 1, // SEND
        recipient: hre.ethers.utils.defaultAbiCoder.encode(
            ['address'],
            [signer.address],
        ),
        minAmountToCreditLD: 1e15,
        amountToSendLD: 1e15,
        composeMsgData: {
            index: 0,
            gas: 0,
            value: 0,
            data: '0x',
            prevData: '0x',
            prevOptionsData: '0x',
        },
    });

    const tx = await tapOFTv2.sendPacket(data.lzSendParam, '0x', {
        value: data.msgFee.nativeFee,
    });
    console.log(`[+] Tx: ${tx.hash}}`);
    await tx.wait(3);
};
