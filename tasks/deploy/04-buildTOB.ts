import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TapiocaOptionBroker__factory } from '../../typechain';
import { IDeployerVMAdd } from '../deployerVM';

export const buildTOB = async (
    hre: HardhatRuntimeEnvironment,
    paymentTokenBeneficiary: string,
    signer: string,
): Promise<IDeployerVMAdd<TapiocaOptionBroker__factory>> => {
    const deploymentName = hre.network.tags['testnet']
        ? 'TapiocaOptionBrokerMock'
        : 'TapiocaOptionBroker';
    return {
        contract: (await hre.ethers.getContractFactory(
            deploymentName,
        )) as TapiocaOptionBroker__factory,
        deploymentName,
        args: [
            // To be replaced by VM
            hre.ethers.constants.AddressZero,
            // To be replaced by VM
            hre.ethers.constants.AddressZero,
            // To be replaced by VM
            hre.ethers.constants.AddressZero,
            paymentTokenBeneficiary,
            signer,
        ],
        dependsOn: [
            {
                argPosition: 0,
                deploymentName: 'TapiocaOptionLiquidityProvision',
            },
            { argPosition: 1, deploymentName: 'TapOFT' },
            { argPosition: 2, deploymentName: 'OTAP' },
        ],
    };
};
