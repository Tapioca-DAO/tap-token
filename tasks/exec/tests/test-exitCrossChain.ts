import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { ILayerZeroEndpoint, TapOFT } from '../../../typechain';
import { BytesLike } from 'ethers';

export const testExitCrossChain__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const signer = (await hre.ethers.getSigners())[0];
    const _srcChainID = await hre.getChainId();
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');

    const srcChain = hre.SDK.utils.getChainBy('chainId', _srcChainID);
    if (!srcChain || srcChain.chainId != _srcChainID)
        throw new Error('[+] Source chain not found');

    console.log('[+] Destination chain:');
    const dstChain = await hre.SDK.hardhatUtils.askForChain();
    if (!dstChain) throw new Error('[+] No destination chain provided');
    if (_srcChainID === String(dstChain.chainId))
        throw new Error('[+] Source and destination chains are the same');

    const tapOFTDepSrc = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TapOFT',
        tag,
    );
    const tapOFTDepDst = hre.SDK.db.getLocalDeployment(
        dstChain.chainId,
        'TapOFT',
        tag,
    );
    if (!tapOFTDepDst)
        throw new Error('[+] TapOFT not found on destination chain');

    const tapOFTSrc = await hre.ethers.getContractAt(
        'TapOFT',
        tapOFTDepSrc.contract.address,
    );

    const { tokenID } = await inquirer.prompt({
        type: 'input',
        name: 'tokenID',
        message: 'Choose the tokenID to unlock',
    });
    const lzEndpoint = await hre.ethers.getContractAt(
        'tapioca-sdk/src/contracts/interfaces/ILayerZeroEndpoint.sol:ILayerZeroEndpoint',
        srcChain.address,
    );

    const dstSendFromFees = await computeDstSendFromValue(
        tag,
        hre,
        dstChain.name,
        dstChain.address,
        {
            tapOFT: await hre.ethers.getContractAt(
                'TapOFT',
                tapOFTDepDst.address,
            ),
            signerAddress: signer.address,
            tokenID: tokenID,
            dstLZChainID: srcChain.lzChainId,
        },
    );

    const adapterParamsForPayload = hre.ethers.utils.solidityPack(
        ['uint16', 'uint', 'uint', 'address'],
        [2, 1_000_000, dstSendFromFees, tapOFTDepDst.address],
    );
    const adapterParamsForSendBack = hre.ethers.utils.solidityPack(
        ['uint16', 'uint256'],
        [1, 200_000],
    );
    const payload = tapOFTSrc.interface.encodeFunctionData(
        'unlockTwTapPosition',
        [
            signer.address,
            tokenID,
            dstChain.lzChainId,
            hre.ethers.constants.AddressZero,
            adapterParamsForPayload,
            {
                adapterParams: adapterParamsForSendBack,
                refundAddress: signer.address,
                zroPaymentAddress: hre.ethers.constants.AddressZero,
            },
        ],
    );
    const { nativeFee } = await lzEndpoint.estimateFees(
        dstChain.lzChainId,
        tapOFTDepSrc.contract.address,
        payload,
        false,
        adapterParamsForPayload,
    );
    console.log(
        '[+] Estimated gas: ',
        hre.ethers.utils.formatEther(nativeFee.toString()),
    );

    console.log('[+] Unlocking TAP');
    const tx = await tapOFTSrc.unlockTwTapPosition(
        signer.address,
        tokenID,
        dstChain.lzChainId,
        hre.ethers.constants.AddressZero,
        adapterParamsForPayload,
        {
            adapterParams: adapterParamsForSendBack,
            refundAddress: signer.address,
            zroPaymentAddress: hre.ethers.constants.AddressZero,
        },
        {
            value: nativeFee,
        },
    );
    console.log(`[+] Tx hash: ${tx.hash}`);
    console.log('[+] Waiting for tx to be mined...');
    await tx.wait(3);
    console.log('[+] Tx mined! 🚀');
};

async function computeDstSendFromValue(
    tag: string,
    hre: HardhatRuntimeEnvironment,
    networkName: any,
    lzAddress: string,
    data: {
        tapOFT: TapOFT;
        signerAddress: string;
        tokenID: string;
        dstLZChainID: string;
    },
) {
    const dstNetwork = await hre.SDK.hardhatUtils.useNetwork(hre, networkName);
    const dstLzEndpoint = (
        await hre.ethers.getContractAt(
            'tapioca-sdk/src/contracts/interfaces/ILayerZeroEndpoint.sol:ILayerZeroEndpoint',
            lzAddress,
        )
    ).connect(dstNetwork.provider) as ILayerZeroEndpoint;

    const twTAPaddy = hre.SDK.db.getLocalDeployment(
        String(await dstNetwork.getChainId()),
        'TwTAP',
        tag,
    );

    if (!twTAPaddy) throw new Error('[+] twTAP not found on destination chain');

    const { tapAmount } = await (
        await hre.ethers.getContractAt('TwTAP', twTAPaddy.address)
    )
        .connect(dstNetwork.provider)
        .getParticipation(data.tokenID);

    const payload = data.tapOFT.interface.encodeFunctionData('sendFrom', [
        data.signerAddress,
        data.dstLZChainID,
        `0x${data.signerAddress.slice(2).padStart(64, '0')}`,
        tapAmount,
        {
            adapterParams: hre.ethers.utils.solidityPack(
                ['uint16', 'uint256'],
                [1, 200_000],
            ),
            refundAddress: hre.ethers.constants.AddressZero,
            zroPaymentAddress: hre.ethers.constants.AddressZero,
        },
    ]);

    const { nativeFee } = await dstLzEndpoint.estimateFees(
        data.dstLZChainID,
        data.tapOFT.address,
        payload,
        false,
        hre.ethers.utils.solidityPack(['uint16', 'uint256'], [1, 200_000]),
    );
    console.log(
        hre.ethers.utils.formatEther(
            (
                await data.tapOFT
                    .connect(dstNetwork.provider)
                    .estimateSendFee(
                        data.dstLZChainID,
                        `0x${data.signerAddress.slice(2).padStart(64, '0')}`,
                        tapAmount,
                        false,
                        hre.ethers.utils.solidityPack(
                            ['uint16', 'uint256'],
                            [1, 200_000],
                        ),
                    )
            ).nativeFee.toString(),
        ),
    );
    console.log(
        '[+] Estimated gas for send back: ',
        hre.ethers.utils.formatEther(nativeFee.toString()),
    );
    return nativeFee;
}
