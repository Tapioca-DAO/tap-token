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

export async function deployGaugeFactory(gauge: string) {
    const gaugeFactory = await (await ethers.getContractFactory('GaugeFactory')).deploy(gauge);
    await gaugeFactory.deployed();

    return gaugeFactory;
}
export async function deployTimedGauge(depositToken: string, rewardToken: string, owner: string, distributor: string) {
    const timedGaugeContract = await (await ethers.getContractFactory('TimedGauge')).deploy();
    await timedGaugeContract.deployed();

    await timedGaugeContract.init(depositToken, rewardToken, owner, distributor);
    return timedGaugeContract;
}

export async function deployLZEndpointMock(chainId: number) {
    const lzEndpointContract = await (await ethers.getContractFactory('LZEndpointMock')).deploy(chainId);
    await lzEndpointContract.deployed();

    return lzEndpointContract;
}

export async function deployTapiocaOFT(lzEndpoint: string, to: string, chainId_?: number) {
    let { chainId } = await ethers.provider.getNetwork();
    chainId = chainId_ ?? chainId;
    const oftContract = await (await ethers.getContractFactory('TapOFT')).deploy(lzEndpoint, to, to, to, to, to, to, chainId);
    await oftContract.deployed();

    return oftContract;
}

export async function deployEsTap(lzEndpoint: string, minter: string, burner: string) {
    const oftContract = await (await ethers.getContractFactory('esTapOFT')).deploy(lzEndpoint, minter, burner);
    await oftContract.deployed();

    return oftContract;
}

export async function deployEsTapVesting(tap: string, esTap: string) {
    const vestingContract = await (await ethers.getContractFactory('esTapVesting')).deploy(tap, esTap);
    await vestingContract.deployed();

    return vestingContract;
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

export async function deployGaugeDistributor(tapToken: string, gaugeController: string) {
    const gaugeDistributorContract = await (await ethers.getContractFactory('GaugeDistributor')).deploy(tapToken, gaugeController);
    await gaugeDistributorContract.deployed();
    return gaugeDistributorContract;
}
