import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const configurePacketTypes__task = async (
    taskArgs: { src: string; dstLzChainId: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const packetTypes = hre.SDK.config.PACKET_TYPES;

    const tapContract = await hre.ethers.getContractAt('TapOFT', taskArgs.src);

    for (let i = 0; i < packetTypes.length; i++) {
        await (
            await tapContract.setMinDstGas(
                taskArgs.dstLzChainId,
                packetTypes[i],
                200000,
            )
        ).wait();
        await (await tapContract.setUseCustomAdapterParams(true)).wait();
    }
    console.log('\nDone');
};
