import { BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

async function resetVM() {
    await ethers.provider.send('hardhat_reset', []);
}

async function mine_blocks(numberOfBlocks: number) {
    for (let i = 0; i < numberOfBlocks; i++) {
        await network.provider.send('evm_mine');
    }
}

async function increase_block_timestamp(time: number) {
    return network.provider.send('evm_increaseTime', [time]);
}

// ---
// exports
// ---

export function BN(n: BigNumberish) {
    return ethers.BigNumber.from(n.toString());
}

export async function time_travel(time: number) {
    increase_block_timestamp(time);
    mine_blocks(1);
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

export async function deployTapiocaOFT(lzEndpoint: string, to: string) {
    const oftContract = await (await ethers.getContractFactory('TapOFT')).deploy(lzEndpoint, to, to, to, to, to, to, to, to);
    await oftContract.deployed();

    return oftContract;
}

export async function deployveTapiocaNFT(tapiocaOFT: string, veTapiocaName: string, veTapiocaSymbol: string, veTapiocaVersion: string) {
    const veTapiocaOFTContract = await (
        await ethers.getContractFactory('VeTap')
    ).deploy(tapiocaOFT, veTapiocaName, veTapiocaSymbol, veTapiocaVersion);
    await veTapiocaOFTContract.deployed();
    return veTapiocaOFTContract;
}

export async function deployGaugeController(tapToken: string, veTapToken: string) {
    const gaugeControllerContract = await (await ethers.getContractFactory('GaugeController')).deploy(tapToken, veTapToken);
    await gaugeControllerContract.deployed();
    return gaugeControllerContract;
}

export async function deployFeeDistributor(
    veTapToken: string,
    startTime: number,
    tapToken: string,
    admin: string,
    emergencyReturn: string,
) {
    const feeDistributorContract = await (
        await ethers.getContractFactory('FeeDistributor')
    ).deploy(veTapToken, startTime, tapToken, admin, emergencyReturn);
    await feeDistributorContract.deployed();
    return feeDistributorContract;
}

export async function deployMinter(tapToken: string, gaugeController: string) {
    const minterContract = await (await ethers.getContractFactory('Minter')).deploy(tapToken, gaugeController);
    await minterContract.deployed();
    return minterContract;
}

export async function deployLiquidityGauge(receipt: string, minter: string, admin: string) {
    const liquidityGauge = await (await ethers.getContractFactory('LiquidityGauge')).deploy(receipt, minter, admin);
    await liquidityGauge.deployed();
    return liquidityGauge;
}
