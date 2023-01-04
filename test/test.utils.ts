import { BigNumberish } from 'ethers';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

// ---
// exports
// ---

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
    const oftContract = await (await ethers.getContractFactory('TapOFT')).deploy(lzEndpoint, to, to, to, to, chainId);
    await oftContract.deployed();

    return oftContract;
}
