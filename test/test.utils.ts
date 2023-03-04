import { BigNumber, BigNumberish, Wallet } from 'ethers';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import hre, { ethers } from 'hardhat';
import BigNumberJs from 'bignumber.js';

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

// ---
// exports
// ---

export async function registerVesting(token: string, cliff: BigNumberish, duration: BigNumberish, staging?: boolean) {
    const vesting = await (await ethers.getContractFactory('Vesting')).deploy(cliff, duration);
    await vesting.deployed();

    return { vesting };
}

export const randomSigners = async (amount: number) => {
    const signers: Wallet[] = [];
    for (let i = 0; i < amount; i++) {
        const signer = new ethers.Wallet(ethers.Wallet.createRandom().privateKey, hre.ethers.provider);
        signers.push(signer);
        await ethers.provider.send('hardhat_setBalance', [
            signer.address,
            ethers.utils.hexStripZeros(ethers.utils.parseEther(String(100000))._hex),
        ]);
    }
    return signers;
};

export function BN(n: BigNumberish) {
    return ethers.BigNumber.from(n.toString());
}

export async function time_travel(time_: number) {
    await time.increase(time_);
}

export type TLZ_Endpoint = {
    [chainId: string]: {
        name: string;
        address: string;
        lzChainId: string;
    };
};

export const LZ_ENDPOINTS: TLZ_Endpoint = {
    '4': {
        name: 'rinkeby',
        address: '0x79a63d6d8BBD5c6dfc774dA79bCcD948EAcb53FA',
        lzChainId: '10001',
    },
    '80001': {
        name: 'mumbai',
        address: '0xf69186dfBa60DdB133E91E9A4B5673624293d8F8',
        lzChainId: '10009',
    },
};
export async function deployUSDC(amount: BigNumberish, decimals: number) {
    const usdc = await (await ethers.getContractFactory('ERC20Mock')).deploy('USDCMock', 'USDCM', amount, decimals);
    await usdc.deployed();

    return usdc;
}
export async function deployLZEndpointMock(chainId: number) {
    const lzEndpointContract = await (await ethers.getContractFactory('LZEndpointMock')).deploy(chainId);
    await lzEndpointContract.deployed();

    return lzEndpointContract;
}
export async function deployUsd0(lzEndpoint: string) {
    const oftContract = await (await ethers.getContractFactory('USD0')).deploy(lzEndpoint);
    await oftContract.deployed();

    return oftContract;
}
export async function deployTapiocaOFT(lzEndpoint: string, to: string, chainId_?: number) {
    let { chainId } = await ethers.provider.getNetwork();
    chainId = chainId_ ?? chainId;
    const oftContract = await (await ethers.getContractFactory('TapOFT')).deploy(lzEndpoint, to, to, to, to, to, chainId);
    await oftContract.deployed();

    return oftContract;
}

export function aml_computeMinWeight(totalWeights: BigNumber, minWeightFactor: BigNumber) {
    return totalWeights.mul(minWeightFactor);
}

export function aml_computeDiscount(magnitude: BigNumber, cumulative: BigNumber, dmin: BigNumber, dmax: BigNumber) {
    if (cumulative.lte(0)) {
        return dmax;
    }
    let target = magnitude.mul(dmax).div(cumulative);
    target = target > dmax ? dmax : target < dmin ? dmin : target;
    return target;
}

export function aml_computeMagnitude(t: BigNumber, cumulative: BigNumber) {
    return sqrt(t.pow(2).add(cumulative.pow(2))).sub(cumulative);
}

export function aml_computeAverageMagnitude(magnitude: BigNumber, averageMagnitude: BigNumber, totalParticipants: BigNumber) {
    return magnitude.add(averageMagnitude).div(totalParticipants);
}

export function aml_computeCumulative(t: BigNumber, cumulative: BigNumber, averageMagnitude: BigNumber) {
    return t > cumulative ? cumulative.add(averageMagnitude) : cumulative.sub(averageMagnitude);
}

function sqrt(value: BigNumber): BigNumber {
    return BigNumber.from(new BigNumberJs(value.toString()).sqrt().toFixed().split('.')[0]);
}
