import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { TContract } from '@tapioca-sdk/shared';
import { IYieldBox } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ERC20WithoutStrategy__factory } from '@tapioca-sdk/typechain/YieldBox';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';
import { loadVM } from 'tasks/utils';
import { yieldbox } from '@typechain/tapioca-periph/interfaces';

export const buildFinalStackPostDepSetup = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<Multicall3.CallStruct[]> => {
    const calls: Multicall3.CallStruct[] = [];
    const signer = (await hre.ethers.getSigners())[0];

    /**
     * Load addresses
     */
    const {
        tapToken,
        oTap,
        tob,
        twTap,
        tOlp,
        yieldbox,
        arbSglGlpDeployment,
        mainnetToftSglDaiDeployment,
        ybStrategyArbSglGlpDeployment,
    } = await loadContract(hre, tag);

    /**
     * Set Singularities on tOLp
     */
    // Check if Arb SGL-GLP is already set
    if (
        (
            await tOlp.activeSingularities(arbSglGlpDeployment.address)
        ).sglAssetID.toNumber() === 0
    ) {
        const ybAsset = await yieldbox.ids(
            1,
            arbSglGlpDeployment.address,
            ybStrategyArbSglGlpDeployment.address,
            0,
        );
        if (ybAsset.toNumber() === 0) {
            console.log('[+] Depositing SGL_GLP to YieldBox');
            const balance = await (
                await hre.ethers.getContractAt(
                    'ERC20',
                    arbSglGlpDeployment.address,
                )
            ).balanceOf(signer.address);
            calls.push({
                target: yieldbox.address,
                allowFailure: false,
                callData: yieldbox.interface.encodeFunctionData(
                    'depositAsset',
                    [
                        ybAsset,
                        signer.address,
                        signer.address,
                        hre.ethers.utils.formatEther(balance),
                        0,
                    ],
                ),
            });
            console.log('\t- Parameters', ybAsset, signer.address, balance, 0);
        }
    }

    /**
     * Set tOB as minter for TapOFT
     */

    if (
        (await tapToken.minter()).toLocaleLowerCase() !==
        tob.address.toLocaleLowerCase()
    ) {
        console.log('[+] Setting tOB as minter for TapToken');
        await (await tapToken.setMinter(tob.address)).wait(1);
        console.log('\t- Parameters', 'tOB', tob.address);
    }

    /**
     * Set tOB Broker role for tOB on oTAP
     */
    if (
        (await oTap.broker()).toLocaleLowerCase() !==
        tOBAddr.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: oTAP broker claim');
        calls.push({
            target: tOBAddr,
            allowFailure: false,
            callData: tob.interface.encodeFunctionData('oTAPBrokerClaim'),
        });
    }

    /**
     * Set twTAP in TapOFT
     */
    if (
        (await tap.twTap()).toLocaleLowerCase() !==
        twTapAddr.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set twTAP in TapToken');
        calls.push({
            target: tapAddr,
            allowFailure: false,
            callData: tap.interface.encodeFunctionData('setTwTAP', [twTapAddr]),
        });
    }
    return calls;
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const tapToken = await hre.ethers.getContractAt(
        'TapToken',
        getContract(hre, tag, DEPLOYMENT_NAMES.TAP_TOKEN).address,
    );
    const twTap = await hre.ethers.getContractAt(
        'TwTAP',
        getContract(hre, tag, DEPLOYMENT_NAMES.TWTAP).address,
    );
    const tob = await hre.ethers.getContractAt(
        'TapiocaOptionBroker',
        getContract(hre, tag, DEPLOYMENT_NAMES.TAPIOCA_OPTION_BROKER).address,
    );
    const oTap = await hre.ethers.getContractAt(
        'OTAP',
        getContract(hre, tag, DEPLOYMENT_NAMES.OTAP).address,
    );
    const tOlp = await hre.ethers.getContractAt(
        'TapiocaOptionLiquidityProvision',
        getContract(
            hre,
            tag,
            DEPLOYMENT_NAMES.TAPIOCA_OPTION_LIQUIDITY_PROVISION,
        ).address,
    );
    const yieldbox = await hre.ethers.getContractAt(
        'IYieldBox',
        getGlobalDeployment(
            hre,
            tag,
            TAPIOCA_PROJECTS_NAME.YieldBox,
            String(hre.network.config.chainId),
            'YIELDBOX', // TODO replace by YB NAME CONFIG
        ).address,
    );

    const arbSglGlpDeployment = getGlobalDeployment(
        hre,
        tag,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        String(hre.network.config.chainId),
        'SGL-GLP', // TODO replace by BAR NAME CONFIG
    );
    const mainnetToftSglDaiDeployment = getGlobalDeployment(
        hre,
        tag,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        hre.SDK.config.EChainID.MAINNET,
        'TOFT-SGL-DAI', // TODO replace by TapiocaZ NAME CONFIG
    );
    const ybStrategyArbSglGlpDeployment = getContract(
        hre,
        tag,
        DEPLOYMENT_NAMES.YB_SGL_GLP_STRATEGY,
    );

    return {
        tapToken,
        twTap,
        tob,
        oTap,
        tOlp,
        yieldbox,
        arbSglGlpDeployment,
        mainnetToftSglDaiDeployment,
        ybStrategyArbSglGlpDeployment,
    };
}

function getContract(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    contractName: string,
) {
    const contract = hre.SDK.db.findLocalDeployment(
        String(hre.network.config.chainId),
        contractName,
        tag,
    )!;
    if (!contract) {
        throw new Error(
            `[-] ${contractName} not found on chain ${hre.network.name} tag ${tag}`,
        );
    }
    return contract;
}

function getGlobalDeployment(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    project: TAPIOCA_PROJECTS_NAME,
    chainId: string,
    contractName: string,
) {
    const contract = hre.SDK.db.findGlobalDeployment(
        project,
        chainId,
        contractName,
        tag,
    )!;
    if (!contract) {
        throw new Error(
            `[-] ${contractName} not found on project ${project} chain ${hre.network.name} tag ${tag}`,
        );
    }
    return contract;
}
