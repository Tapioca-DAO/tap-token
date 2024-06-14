import { TapiocaMulticall } from '@tapioca-sdk/typechain/tapioca-periphery';
import {
    AOTAP__factory,
    AirdropBroker__factory,
    TapToken__factory,
} from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import { loadTapTokenLocalContract } from 'tasks/utils';

export const buildPostLbpStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<TapiocaMulticall.CallStruct[]> => {
    const calls: TapiocaMulticall.CallStruct[] = [];

    /**
     * Load contracts
     */
    const { adb, tapToken, aoTap } = await loadContract(hre, tag);

    /**
     * Broker claim for AOTAP
     */
    if ((await aoTap.broker()) !== adb.address) {
        console.log('[+] +Call queue: AOTAP broker claim');
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('aoTAPBrokerClaim'),
        });
    }

    /**
     * Set tapToken in ADB
     */
    if (
        (await adb.tapToken()).toLocaleLowerCase() !==
        tapToken.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set TapToken in AirdropBroker');
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setTapToken', [
                tapToken.address,
            ]),
        });
        console.log('\t- Parameters:', 'TapToken', tapToken.address);
    }

    return calls;
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const tapToken = TapToken__factory.connect(
        loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.TAP_TOKEN).address,
        hre.ethers.provider.getSigner(),
    );
    const adb = AirdropBroker__factory.connect(
        loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.AIRDROP_BROKER)
            .address,
        hre.ethers.provider.getSigner(),
    );
    const aoTap = AOTAP__factory.connect(
        loadTapTokenLocalContract(hre, tag, DEPLOYMENT_NAMES.AOTAP).address,
        hre.ethers.provider.getSigner(),
    );

    return {
        tapToken,
        adb,
        aoTap,
    };
}
