import { BigNumber, BigNumberish, Signature, Wallet } from 'ethers';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import hre, { ethers } from 'hardhat';
import BigNumberJs from 'bignumber.js';
import { splitSignature } from 'ethers/lib/utils';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Permit, ERC721Permit } from '../typechain';

import {
    ERC20Mock__factory,
    LZEndpointMock__factory,
} from '../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

// ---
// exports
// ---

export async function registerVesting(
    token: string,
    cliff: BigNumberish,
    duration: BigNumberish,
    owner: string,
    staging?: boolean,
) {
    const vesting = await (
        await ethers.getContractFactory('Vesting')
    ).deploy(cliff, duration, owner);
    await vesting.deployed();

    return { vesting };
}

export const randomSigners = async (amount: number) => {
    const signers: Wallet[] = [];
    for (let i = 0; i < amount; i++) {
        const signer = new ethers.Wallet(
            ethers.Wallet.createRandom().privateKey,
            hre.ethers.provider,
        );
        signers.push(signer);
        await ethers.provider.send('hardhat_setBalance', [
            signer.address,
            ethers.utils.hexStripZeros(
                ethers.utils.parseEther(String(100000))._hex,
            ),
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
export async function deployUSDC(
    amount: BigNumberish,
    decimals: number,
    owner: any,
) {
    const ERC20Mock = new ERC20Mock__factory(owner);
    const usdc = await ERC20Mock.deploy(
        'USDCMock',
        'USDCM',
        amount,
        decimals,
        owner.address,
    );
    await usdc.updateMintLimit(ethers.constants.MaxUint256);

    return usdc;
}
export async function deployLZEndpointMock(chainId: number) {
    const deployer = (await ethers.getSigners())[0];
    const LZEndpointMock = new LZEndpointMock__factory(deployer);
    const lzEndpointContract = await LZEndpointMock.deploy(chainId);

    return lzEndpointContract;
}
export async function deployUsd0(lzEndpoint: string) {
    const oftContract = await (
        await ethers.getContractFactory('USD0')
    ).deploy(lzEndpoint);
    await oftContract.deployed();

    return oftContract;
}
export async function deployTapiocaOFT(
    signer: SignerWithAddress,
    lzEndpoint: string,
    to: string,
    chainId_?: number,
) {
    let { chainId } = await ethers.provider.getNetwork();
    chainId = chainId_ ?? chainId;
    const oftContract = await (
        await ethers.getContractFactory('TapOFT')
    ).deploy(lzEndpoint, to, to, to, to, to, to, chainId, signer.address);
    await oftContract.deployed();
    await oftContract.setMinter(signer.address);

    return oftContract;
}

export function aml_computeMinWeight(
    totalWeights: BigNumber,
    minWeightFactor: BigNumber,
) {
    return totalWeights.mul(minWeightFactor);
}

export function aml_computeTarget(
    magnitude: BigNumber,
    cumulative: BigNumber,
    dmin: BigNumber,
    dmax: BigNumber,
) {
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

export function aml_computeAverageMagnitude(
    magnitude: BigNumber,
    averageMagnitude: BigNumber,
    totalParticipants: BigNumber,
) {
    return magnitude.add(averageMagnitude).div(totalParticipants);
}

export function aml_computeCumulative(
    t: BigNumber,
    cumulative: BigNumber,
    averageMagnitude: BigNumber,
) {
    return t > cumulative
        ? cumulative.add(averageMagnitude)
        : cumulative.sub(averageMagnitude);
}

function sqrt(value: BigNumber): BigNumber {
    return BigNumber.from(
        new BigNumberJs(value.toString()).sqrt().toFixed().split('.')[0],
    );
}

export async function getERC20PermitSignature(
    wallet: Wallet | SignerWithAddress,
    token: ERC20Permit,
    spender: string,
    value: BigNumberish = ethers.constants.MaxUint256,
    deadline = ethers.constants.MaxUint256,
    permitConfig?: {
        nonce?: BigNumberish;
        name?: string;
        chainId?: number;
        version?: string;
    },
): Promise<Signature> {
    const [nonce, name, version, chainId] = await Promise.all([
        permitConfig?.nonce ?? token.nonces(wallet.address),
        permitConfig?.name ?? token.name(),
        permitConfig?.version ?? '1',
        permitConfig?.chainId ?? wallet.getChainId(),
    ]);

    return splitSignature(
        await wallet._signTypedData(
            {
                name,
                version,
                chainId,
                verifyingContract: token.address,
            },
            {
                Permit: [
                    {
                        name: 'owner',
                        type: 'address',
                    },
                    {
                        name: 'spender',
                        type: 'address',
                    },
                    {
                        name: 'value',
                        type: 'uint256',
                    },
                    {
                        name: 'nonce',
                        type: 'uint256',
                    },
                    {
                        name: 'deadline',
                        type: 'uint256',
                    },
                ],
            },
            {
                owner: wallet.address,
                spender,
                value,
                nonce,
                deadline,
            },
        ),
    );
}

export async function getERC721PermitSignature(
    wallet: Wallet | SignerWithAddress,
    token: ERC721Permit,
    spender: string,
    tokenId: BigNumberish,
    deadline = ethers.constants.MaxUint256,
    permitConfig?: {
        nonce?: BigNumberish;
        name?: string;
        chainId?: number;
        version?: string;
    },
): Promise<Signature> {
    const [nonce, name, version, chainId] = await Promise.all([
        permitConfig?.nonce ?? token.nonces(wallet.address),
        permitConfig?.name ?? token.name(),
        permitConfig?.version ?? '1',
        permitConfig?.chainId ?? wallet.getChainId(),
    ]);

    return splitSignature(
        await wallet._signTypedData(
            {
                name,
                version,
                chainId,
                verifyingContract: token.address,
            },
            {
                Permit: [
                    {
                        name: 'spender',
                        type: 'address',
                    },
                    {
                        name: 'tokenId',
                        type: 'uint256',
                    },
                    {
                        name: 'nonce',
                        type: 'uint256',
                    },
                    {
                        name: 'deadline',
                        type: 'uint256',
                    },
                ],
            },
            {
                owner: wallet.address,
                spender,
                tokenId,
                nonce,
                deadline,
            },
        ),
    );
}
