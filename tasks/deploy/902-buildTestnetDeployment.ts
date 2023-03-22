import { ContractFactory } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import {
    ERC20Mock__factory,
    OracleMock__factory,
    YieldBoxVaultStrat__factory,
} from '../../typechain';

export const buildTestnetDeployment = async (
    hre: HardhatRuntimeEnvironment,
    owner: string,
): Promise<IDeployerVMAdd<ContractFactory>[]> => {
    if (!hre.network.tags['testnet']) {
        throw new Error('[-] This builder is only for testnet');
    }

    const tapOracleMock: IDeployerVMAdd<OracleMock__factory> = {
        contract: await hre.ethers.getContractFactory('OracleMock'),
        deploymentName: 'TapOFTOracleMock',
        args: ['TOFTOM'],
    };

    const sglTokenMock1: IDeployerVMAdd<ERC20Mock__factory> = {
        contract: await hre.ethers.getContractFactory('ERC20Mock'),
        deploymentName: 'sglTokenMock1',
        args: ['sglTokenMock1', 'SGL1', 18, 0, owner],
    };

    const sglTokenMock2: IDeployerVMAdd<ERC20Mock__factory> = {
        contract: await hre.ethers.getContractFactory('ERC20Mock'),
        deploymentName: 'sglTokenMock2',
        args: ['sglTokenMock2', 'SGL2', 18, 0, owner],
    };

    const wethMock: IDeployerVMAdd<ERC20Mock__factory> = {
        contract: await hre.ethers.getContractFactory('ERC20Mock'),
        deploymentName: 'WETHMock',
        args: ['wethMock', 'WETHM', 18, 0, owner],
    };

    const usdcMock: IDeployerVMAdd<ERC20Mock__factory> = {
        contract: await hre.ethers.getContractFactory('ERC20Mock'),
        deploymentName: 'USDCMock',
        args: ['usdcMock', 'USDCM', 6, 0, owner],
    };

    const wethMOracleMock: IDeployerVMAdd<OracleMock__factory> = {
        contract: await hre.ethers.getContractFactory('OracleMock'),
        deploymentName: 'WETHMOracleMock',
        args: ['WETHMOracle'],
    };

    const usdcMOracleMock: IDeployerVMAdd<OracleMock__factory> = {
        contract: await hre.ethers.getContractFactory('OracleMock'),
        deploymentName: 'USDCMOracleMock',
        args: ['USDCMOracle'],
    };

    const yieldBoxVaultStratSGlTokenMock1: IDeployerVMAdd<YieldBoxVaultStrat__factory> =
        {
            contract: await hre.ethers.getContractFactory('YieldBoxVaultStrat'),
            deploymentName: 'YieldBoxVaultStratSGlTokenMock1',
            args: [
                hre.ethers.constants.AddressZero, // To be replaced by VM
                sglTokenMock1.deploymentName, // To be replaced by VM
                'YBVaultStratSGLTKN1',
                'YBVaultStrat for sglTokenMock1',
            ],
            dependsOn: [
                {
                    argPosition: 0,
                    deploymentName: 'YieldBoxMock',
                },
                {
                    argPosition: 1,
                    deploymentName: sglTokenMock1.deploymentName,
                },
            ],
        };

    const yieldBoxVaultStratSGlTokenMock2: IDeployerVMAdd<YieldBoxVaultStrat__factory> =
        {
            contract: await hre.ethers.getContractFactory('YieldBoxVaultStrat'),
            deploymentName: 'YieldBoxVaultStratSGlTokenMock2',
            args: [
                hre.ethers.constants.AddressZero, // To be replaced by VM
                sglTokenMock1.deploymentName, // To be replaced by VM
                'YBVaultStratSGLTKN2',
                'YBVaultStrat for sglTokenMock2',
            ],
            dependsOn: [
                {
                    argPosition: 0,
                    deploymentName: 'YieldBoxMock',
                },
                {
                    argPosition: 1,
                    deploymentName: sglTokenMock2.deploymentName,
                },
            ],
        };

    return [
        tapOracleMock,
        sglTokenMock1,
        sglTokenMock2,
        wethMock,
        usdcMock,
        wethMOracleMock,
        usdcMOracleMock,
        yieldBoxVaultStratSGlTokenMock1,
        yieldBoxVaultStratSGlTokenMock2,
    ];
};
