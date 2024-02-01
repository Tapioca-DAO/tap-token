import { EChainID } from '@tapioca-sdk/api/config';
import {
    SeerCLSolo__factory,
    SeerUniSolo__factory,
    TapiocaMulticall,
} from '@tapioca-sdk/typechain/tapioca-periphery';
import { Token } from '@uniswap/sdk-core';
import { FeeAmount, computePoolAddress } from '@uniswap/v3-sdk';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from 'tasks/deploy/DEPLOY_CONFIG';
import { loadVM } from 'tasks/utils';

/**
 * Used to deploy contract like the Uniswap V3 pool for the TAP-WETH pair first
 */
export const buildPostLbpStackPostDepSetup_1 = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<TapiocaMulticall.CallStruct[]> => {
    const calls: TapiocaMulticall.CallStruct[] = [];
    const signer = (await hre.ethers.getSigners())[0];
    const VM = await loadVM(hre, tag);

    /**
     * Load contracts
     */
    const { tapToken, uniV3Factory, weth } = await loadContract(hre, tag);

    const computedPoolAddress = computePoolAddress({
        factoryAddress: uniV3Factory.address,
        tokenA: new Token(hre.network.config.chainId!, tapToken.address, 18),
        tokenB: new Token(hre.network.config.chainId!, weth.address, 18),
        fee: FeeAmount.MEDIUM,
    });

    let newPool = false;
    /**
     * Deploy Uniswap V3 Pool if not deployed
     */
    if (
        (
            await uniV3Factory.getPool(
                tapToken.address,
                weth.address,
                FeeAmount.MEDIUM,
            )
        ).toLocaleLowerCase() ===
        hre.ethers.constants.AddressZero.toLocaleLowerCase()
    ) {
        newPool = true;
        console.log('[+] +Call queue: Deploy Uniswap V3 Pool');
        calls.push({
            target: uniV3Factory.address,
            allowFailure: false,
            callData: uniV3Factory.interface.encodeFunctionData('createPool', [
                tapToken.address,
                weth.address,
                FeeAmount.MEDIUM,
            ]),
        });
        console.log(
            '\t- Parameters:',
            'Token0',
            tapToken.address,
            'Token1',
            weth.address,
            'Fee',
            FeeAmount.MEDIUM,
        );

        VM.load([
            {
                name: DEPLOYMENT_NAMES.TAP_WETH_UNI_V3_POOL,
                address: computedPoolAddress,
                meta: {
                    tap: tapToken.address,
                    weth: weth.address,
                    fee: FeeAmount.MEDIUM,
                },
            },
        ]);
        await VM.save();
    }

    /**
     * Deploy TAP oracle if new pool was deployed
     */
    if (newPool) {
        // TODO Use TAP/WETH UNI => WETH/USDC UNI for now. Change to TAP/WETH UNI => WETH/USDC CL when possible
        const tapOracle = await new SeerUniSolo__factory(signer).deploy(
            DEPLOY_CONFIG.POST_LBP[
                hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.POST_LBP
            ].TAP_ORACLE.NAME,
            DEPLOY_CONFIG.POST_LBP[
                hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.POST_LBP
            ].TAP_ORACLE.NAME,
            18,
            {
                addressInAndOutUni: [tapToken.address, weth.address],
                _circuitUniswap: [
                    computedPoolAddress, /// TAP/WETH
                    DEPLOY_CONFIG.POST_LBP[
                        hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.MISC
                    ].TAP_ORACLE.WETH_USDC_UNI_POOL, // WETH-USDC Uniswap V3 Pool. 500 FeeAmount
                ],
                _circuitUniIsMultiplied: [1, 0], // Multiply/divide Uni
                _twapPeriod: 600, // 5min TWAP
                observationLength: 10, // 10 min Observation length
                guardians: [signer.address], // Owner
                _description:
                    DEPLOY_CONFIG.POST_LBP[
                        hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.MISC
                    ].TAP_ORACLE.DESCRIPTION, // Description,
                _sequencerUptimeFeed:
                    DEPLOY_CONFIG.MISC[
                        hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.MISC
                    ].CL_SEQUENCER,
                _admin: signer.address, // Owner
            },
        );
        await tapOracle.deployed();
        VM.load([
            {
                name: DEPLOYMENT_NAMES.TAP_ORACLE,
                address: tapOracle.address,
                meta: {
                    _circuitUniswap: [
                        computedPoolAddress, /// TAP/WETH
                        DEPLOY_CONFIG.POST_LBP[
                            hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.MISC
                        ].TAP_ORACLE.WETH_USDC_UNI_POOL, // WETH-USDC Uniswap V3 Pool. 500 FeeAmount
                    ],
                },
            },
        ]);
        await VM.save();
    }

    /**
     * Deploy USDC oracle if not deployed
     */
    try {
        getContract(hre, tag, DEPLOYMENT_NAMES.USDC_USDC_CL_POOl);
    } catch (err) {
        const usdcOracle = await new SeerCLSolo__factory(signer).deploy(
            'USDC/USD',
            'USDC/USD',
            18,
            {
                _poolChainlink:
                    DEPLOY_CONFIG.POST_LBP[
                        hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.POST_LBP
                    ].TAP_ORACLE.ETH_USD_CHAINLINK, // CL Pool
                _isChainlinkMultiplied: 1,
                stalePeriod: 86400, // CL stale period, 1 day
                guardians: [signer.address],
                _description: hre.ethers.utils.formatBytes32String('ETH/USD'), // Description,
                _sequencerUptimeFeed:
                    DEPLOY_CONFIG.MISC[
                        hre.SDK.eChainId as keyof typeof DEPLOY_CONFIG.MISC
                    ].CL_SEQUENCER,
                _inBase: (1e18).toString(),
                _admin: signer.address,
            },
        );
        await usdcOracle.deployed();
        VM.load([
            {
                name: DEPLOYMENT_NAMES.USDC_USDC_CL_POOl,
                address: usdcOracle.address,
                meta: {
                    CL_POOL:
                        DEPLOY_CONFIG.POST_LBP[
                            hre.SDK
                                .eChainId as keyof typeof DEPLOY_CONFIG.POST_LBP
                        ].TAP_ORACLE.ETH_USD_CHAINLINK,
                },
            },
        ]);
        await VM.save();
    }

    return calls;
};

export const buildPostLbpStackPostDepSetup_2 = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
): Promise<TapiocaMulticall.CallStruct[]> => {
    const calls: TapiocaMulticall.CallStruct[] = [];

    /**
     * Load contracts
     */
    const { adb, tapToken, tapOracleDeployment, usdcOracleDeployment, aoTap } =
        await loadContract(hre, tag);

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

    /**
     * Set Tap oracle in ADB
     */
    if (
        (await adb.tapToken()).toLocaleLowerCase() !==
        tapOracleDeployment.address.toLocaleLowerCase()
    ) {
        console.log('[+] +Call queue: set TapToken in AirdropBroker');
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setTapOracle', [
                tapOracleDeployment.address,
                '0x00',
            ]),
        });
    }

    /**
     * Set USDC as payment token in ADB
     */
    const usdcAddr =
        DEPLOY_CONFIG.POST_LBP[EChainID.ARBITRUM].ADB.USDC_PAYMENT_TOKEN;
    if (
        (await adb.paymentTokens(usdcAddr)).oracle.toLocaleLowerCase() !==
        usdcOracleDeployment.address.toLocaleLowerCase()
    ) {
        console.log(
            '[+] +Call queue: set USDC as payment token in AirdropBroker',
        );
        calls.push({
            target: adb.address,
            allowFailure: false,
            callData: adb.interface.encodeFunctionData('setPaymentToken', [
                usdcAddr,
                usdcOracleDeployment.address,
                '0x00',
            ]),
        });
        console.log(
            '\t- Parameters:',
            'USDC',
            usdcAddr,
            'USDC Oracle',
            usdcOracleDeployment.address,
            'Oracle Data',
            '0x00',
        );
    }

    return calls;
};

async function loadContract(hre: HardhatRuntimeEnvironment, tag: string) {
    const tapOracleDeployment = getContract(
        hre,
        tag,
        DEPLOYMENT_NAMES.TAP_ORACLE,
    );

    const usdcOracleDeployment = getContract(
        hre,
        tag,
        DEPLOYMENT_NAMES.USDC_USDC_CL_POOl,
    );

    const weth = await hre.ethers.getContractAt(
        'ERC20',
        DEPLOY_CONFIG.MISC[
            String(
                hre.network.config.chainId,
            ) as keyof typeof DEPLOY_CONFIG.MISC
        ].WETH,
    );
    const tapToken = await hre.ethers.getContractAt(
        'TapToken',
        getContract(hre, tag, DEPLOYMENT_NAMES.TAP_TOKEN).address,
    );
    const adb = await hre.ethers.getContractAt(
        'AirdropBroker',
        getContract(hre, tag, DEPLOYMENT_NAMES.AIRDROP_BROKER).address,
    );
    const aoTap = await hre.ethers.getContractAt(
        'AOTAP',
        getContract(hre, tag, DEPLOYMENT_NAMES.AOTAP).address,
    );
    const uniV3Factory = await hre.ethers.getContractAt(
        'IUniswapV3Factory',
        DEPLOY_CONFIG.UNISWAP.V3_FACTORY,
    );

    return {
        tapToken,
        adb,
        tapOracleDeployment,
        usdcOracleDeployment,
        aoTap,
        weth,
        uniV3Factory,
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
