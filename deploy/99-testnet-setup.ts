import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import SDK from 'tapioca-sdk';
import { deployERC20Mock__task, deployOracleMock__task } from '../tasks/contractDeployment';
import {
    setOracleMockRate__task,
    setTOBPaymentToken__task,
    setTOLPRegisterSingularity__task,
    setYieldBoxRegisterAsset__task,
} from '../tasks/setterTasks';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const chainId = await hre.getChainId();

    const yieldBox = await hre.ethers.getContractAt('YieldBox', SDK.API.utils.getDeployment('Tapioca-Bar', 'YieldBox', chainId).address);

    if (hre.network.tags['testnet']) {
        await deployERC20Mock__task(
            { name: 'sglTokenMock1', symbol: 'sgl1', decimals: '18', deploymentName: 'sglTokenMock1', initialAmount: '0' },
            hre,
        );
        await deployERC20Mock__task(
            { name: 'sglTokenMock2', symbol: 'sgl2', decimals: '18', deploymentName: 'sglTokenMock2', initialAmount: '0' },
            hre,
        );

        const sglTokenMock1Meta = SDK.API.utils.getDeployment('Tap-Token', 'sglTokenMock1', chainId);
        const sglTokenMock2Meta = SDK.API.utils.getDeployment('Tap-Token', 'sglTokenMock2', chainId);
        const sgl1AssetID = await setYieldBoxRegisterAsset__task(
            { tknAddress: sglTokenMock1Meta.address, strategyName: 'STM1-Vault', strategyDesc: 'sglTokenMock1 vault' },
            hre,
        );
        const sgl2AssetID = await setYieldBoxRegisterAsset__task(
            { tknAddress: sglTokenMock1Meta.address, strategyName: 'STM2-Vault', strategyDesc: 'sglTokenMock2 vault' },
            hre,
        );

        await setTOLPRegisterSingularity__task(
            { assetId: sgl1AssetID.toString(), sglAddress: sglTokenMock1Meta.address, weight: '0' },
            hre,
        );
        await setTOLPRegisterSingularity__task(
            { assetId: sgl2AssetID.toString(), sglAddress: sglTokenMock2Meta.address, weight: '0' },
            hre,
        );

        await deployERC20Mock__task(
            { name: 'wethMock', symbol: 'WETHM', decimals: '18', deploymentName: 'WETHMock', initialAmount: '0' },
            hre,
        );
        await deployERC20Mock__task(
            { name: 'usdcMock', symbol: 'USDCM', decimals: '6', deploymentName: 'USDCMock', initialAmount: '0' },
            hre,
        );

        await deployOracleMock__task({ deploymentName: 'WETHMOracleMock', erc20Name: 'WETHMOracle' }, hre);
        await deployOracleMock__task({ deploymentName: 'USDCMOracleMock', erc20Name: 'USDCMOracle' }, hre);

        const wethmOracleMockMeta = SDK.API.utils.getDeployment('Tap-Token', 'WETHMOracleMock', chainId);
        const usdcmOracleMockMeta = SDK.API.utils.getDeployment('Tap-Token', 'USDCMOracleMock', chainId);
        await setOracleMockRate__task({ oracleAddress: wethmOracleMockMeta.address, rate: '1480000000000000000000' }, hre);
        await setOracleMockRate__task({ oracleAddress: usdcmOracleMockMeta.address, rate: '1000000' }, hre);

        const wethMMeta = SDK.API.utils.getDeployment('Tap-Token', 'WETHMock', chainId);
        const usdcMMeta = SDK.API.utils.getDeployment('Tap-Token', 'USDCMock', chainId);

        await setTOBPaymentToken__task(
            { tknAddress: wethMMeta.address, oracleAddress: wethmOracleMockMeta.address, oracleData: '0x00' },
            hre,
        );
        await setTOBPaymentToken__task(
            { tknAddress: usdcMMeta.address, oracleAddress: usdcmOracleMockMeta.address, oracleData: '0x00' },
            hre,
        );
    }
};

export default func;
func.tags = ['testnet-setup'];
