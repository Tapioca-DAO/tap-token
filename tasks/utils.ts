import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import { TContract } from 'tapioca-sdk/dist/shared';
import { getDeployments } from './getDeployments';

export const getGaugeControllerContract = async (hre: HardhatRuntimeEnvironment) => {
    let deployments: TContract[] = [];
    try {
        deployments = await getDeployments(hre, true);
    } catch (e) {
        deployments = await getDeployments(hre);
    }

    const gaugeController = _.find(deployments, { name: 'gaugeController' });
    if (!gaugeController) {
        throw new Error('[-] GaugeController not found');
    }

    const gaugeControllerContract = await hre.ethers.getContractAt('GaugeController', gaugeController.address);

    return { gaugeControllerContract };
};

export const getGaugeContract = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    let deployments: TContract[] = [];
    try {
        deployments = await getDeployments(hre, true);
    } catch (e) {
        deployments = await getDeployments(hre);
    }

    const gaugeAddress = taskArgs['gauge'];
    const gaugeContract = await hre.ethers.getContractAt('TimedGauge', gaugeAddress);

    return { gaugeContract, gaugeAddress };
};

export const getVotingEscrowContract = async (hre: HardhatRuntimeEnvironment) => {
    let deployments: TContract[] = [];
    try {
        deployments = await getDeployments(hre, true);
    } catch (e) {
        deployments = await getDeployments(hre);
    }

    const ve = _.find(deployments, { name: 'veTap' });
    if (!ve) {
        throw new Error('[-] VotingEscrow not found');
    }

    const votingEscrowContract = await hre.ethers.getContractAt('VotingEscrow', ve.address);
    return { votingEscrowContract };
};

export const getBoostContract = async (hre: HardhatRuntimeEnvironment) => {
    let deployments: TContract[] = [];
    try {
        deployments = await getDeployments(hre, true);
    } catch (e) {
        deployments = await getDeployments(hre);
    }

    const boost = _.find(deployments, { name: 'boostV2' });
    if (!boost) {
        throw new Error('[-] BoostV2 not found');
    }

    const boostContract = await hre.ethers.getContractAt('BoostV2', boost.address);
    return { boostContract };
};

export const getTapContract = async (hre: HardhatRuntimeEnvironment) => {
    let deployments: TContract[] = [];
    try {
        deployments = await getDeployments(hre, true);
    } catch (e) {
        deployments = await getDeployments(hre);
    }

    const tapOft = _.find(deployments, { name: 'tapOFT' });
    if (!tapOft) {
        throw new Error('[-] TapOFT not found');
    }

    const tapOFTContract = await hre.ethers.getContractAt('TapOFT', tapOft.address);
    return { tapOFTContract };
};
