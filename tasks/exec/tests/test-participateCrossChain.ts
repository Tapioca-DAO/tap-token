import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';

export const testParticipateCrossChain__task = async (
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

    const { amountToLock } = await inquirer.prompt({
        type: 'input',
        name: 'amountToLock',
        message: 'Choose the amount of TAP to lock',
    });

    /**
     * Send TapOFT
     */

    // const _payload = tapOFTSrc.interface.encodeFunctionData('sendFrom', [
    //     signer.address,
    //     dstChain.lzChainId,
    //     `0x${signer.address.slice(2).padStart(64, '0')}`,
    //     (1e18).toString(),
    //     {
    //         adapterParams: hre.ethers.utils.solidityPack(
    //             ['uint16', 'uint256'],
    //             [1, 200_000], // Should use ~514_227
    //         ),
    //         refundAddress: signer.address,
    //         zroPaymentAddress: hre.ethers.constants.AddressZero,
    //     },
    // ]);

    // const _lzEndpoint = await hre.ethers.getContractAt(
    //     'tapioca-sdk/src/contracts/interfaces/ILayerZeroEndpoint.sol:ILayerZeroEndpoint',
    //     srcChain.address,
    // );
    // const { nativeFee: _nativeFee } = await _lzEndpoint.estimateFees(
    //     dstChain.lzChainId,
    //     tapOFTDepDst.address,
    //     _payload,
    //     false,
    //     hre.ethers.utils.solidityPack(
    //         ['uint16', 'uint256'],
    //         [1, 200_000], // Should use ~514_227
    //     ),
    // );
    // const _tx = await tapOFTSrc.sendFrom(
    //     signer.address,
    //     dstChain.lzChainId,
    //     `0x${signer.address.slice(2).padStart(64, '0')}`,
    //     (1e18).toString(),
    //     {
    //         adapterParams: hre.ethers.utils.solidityPack(
    //             ['uint16', 'uint256'],
    //             [1, 200_000], // Should use ~514_227
    //         ),
    //         refundAddress: signer.address,
    //         zroPaymentAddress: hre.ethers.constants.AddressZero,
    //     },
    //     { value: _nativeFee },
    // );
    // console.log(_tx.hash);
    // await _tx.wait(3);

    // return;

    const { lockDuration } = await inquirer.prompt({
        type: 'input',
        name: 'lockDuration',
        message: 'Choose the lock duration (in seconds)',
    });

    const lzEndpoint = await hre.ethers.getContractAt(
        'tapioca-sdk/src/contracts/interfaces/ILayerZeroEndpoint.sol:ILayerZeroEndpoint',
        srcChain.address,
    );

    const payload = tapOFTSrc.interface.encodeFunctionData(
        'lockTwTapPosition',
        [
            signer.address,
            amountToLock,
            lockDuration,
            dstChain.lzChainId,
            hre.ethers.constants.AddressZero,
            hre.ethers.utils.solidityPack(
                ['uint16', 'uint256'],
                [1, 550_000], // Should use ~514_227
            ),
        ],
    );
    const { nativeFee } = await lzEndpoint.estimateFees(
        dstChain.lzChainId,
        tapOFTDepDst.address,
        payload,
        false,
        hre.ethers.utils.solidityPack(
            ['uint16', 'uint256'],
            [1, 550_000], // Should use ~514_227
        ),
    );
    console.log(
        '[+] Estimated gas: ',
        hre.ethers.utils.formatEther(nativeFee.toString()),
    );

    console.log('[+] Locking TAP');
    const tx = await tapOFTSrc.lockTwTapPosition(
        signer.address,
        amountToLock,
        lockDuration,
        dstChain.lzChainId,
        hre.ethers.constants.AddressZero,
        hre.ethers.utils.solidityPack(
            ['uint16', 'uint256'],
            [1, 550_000], // Should use ~514_227
        ),
        {
            value: nativeFee,
        },
    );
    console.log(`[+] Tx hash: ${tx.hash}`);
    console.log('[+] Waiting for tx to be mined...');
    await tx.wait(3);
    console.log('[+] Tx mined! 🚀');
};
