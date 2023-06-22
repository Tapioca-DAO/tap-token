import hre, { ethers } from 'hardhat';
import {
    ERC20Mock__factory,
    ERC721Mock__factory,
    LZEndpointMock__factory,
    OracleMock__factory,
} from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';

import { BigNumberish, Wallet } from 'ethers';
import { ERC721Mock } from 'tapioca-sdk/dist/typechain/tapioca-mocks';
import { BN, randomSigners } from '../test.utils';
import MerkleTree from 'merkletreejs';
import PHASE2_ALLOW_LIST from '../../output.json';

interface IPhase2AllowList {
    signers: {
        address: string;
        pk: string;
    }[];
    role: number;
}

export const setupFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];
    const users = (await hre.ethers.getSigners()).splice(1);
    const paymentTokenBeneficiary = new hre.ethers.Wallet(
        hre.ethers.Wallet.createRandom().privateKey,
        hre.ethers.provider,
    );

    const chainId = (await ethers.provider.getNetwork()).chainId;

    // LZ Endpoint Mocks
    const LZEndpointMock = new LZEndpointMock__factory(signer);
    const LZEndpointMockCurrentChain = await LZEndpointMock.deploy(chainId);
    const LZEndpointMockGovernance = await LZEndpointMock.deploy(11);

    // Tap OFT
    const _to = signer.address;
    const tapOFT = await (
        await ethers.getContractFactory('TapOFT')
    ).deploy(
        LZEndpointMockCurrentChain.address,
        _to,
        _to,
        _to,
        _to,
        _to,
        _to,
        chainId,
        signer.address,
    );
    const OracleMock = new OracleMock__factory(signer);

    // PCNFT
    const pcnft = await new ERC721Mock__factory(signer).deploy(
        'PCNFT',
        'PCNFT',
    );
    const tapOracleMock = await OracleMock.deploy('TAP', 'TAP', BN(33e17));

    // aoTAP
    const aoTAP = await (
        await ethers.getContractFactory('AOTAP')
    ).deploy(signer.address);
    const adb = await (
        await hre.ethers.getContractFactory('AirdropBroker')
    ).deploy(
        aoTAP.address,
        tapOFT.address,
        pcnft.address,
        paymentTokenBeneficiary.address,
        signer.address,
    );
    await adb.setTapOracle(tapOracleMock.address, '0x00');

    // Deploy payment tokens
    const ERC20Mock = new ERC20Mock__factory(signer);
    const stableMock = await ERC20Mock.deploy(
        'StableMock',
        'STBLM',
        0,
        6,
        signer.address,
    );
    await stableMock.updateMintLimit(ethers.constants.MaxUint256);
    const ethMock = await ERC20Mock.deploy(
        'wethMock',
        'WETHM',
        0,
        18,
        signer.address,
    );
    await ethMock.updateMintLimit(ethers.constants.MaxUint256);

    const stableMockOracle = await OracleMock.deploy(
        'StableMockOracle',
        'SMO',
        (1e18).toString(),
    );
    const ethMockOracle = await OracleMock.deploy(
        'WETHMockOracle',
        'WMO',
        BN(1e18).mul(1200),
    );

    const phase2Users: IPhase2AllowList[] = PHASE2_ALLOW_LIST;
    return {
        // signers
        signer,
        users,
        paymentTokenBeneficiary,
        phase2Users,

        // vars
        LZEndpointMockCurrentChain,
        LZEndpointMockGovernance,
        tapOFT,
        pcnft,
        aoTAP,
        adb,

        tapOracleMock,

        // Payment tokens
        stableMock,
        ethMock,
        stableMockOracle,
        ethMockOracle,

        // Functions
        generatePhase1_4Signers,
        generatePhase2MerkleTree,
        generatePhase3Signers,

        generatePhase2Data,
        generatePhase3Data,
    };
};

const generatePhase1_4Signers = async (initialAmount: number) => {
    let remainingAmount = initialAmount;

    const signers: { wallet: Wallet; amount: BigNumberish }[] = [];
    const rndSigners = await randomSigners(100); // pre-computed random signers

    while (remainingAmount > 0) {
        const amount = Math.floor(Math.random() * 100_000);
        remainingAmount -= amount;
        const wallet = rndSigners.pop();
        if (wallet === undefined) break;
        signers.push({
            wallet,
            amount,
        });
    }

    return signers;
};

const generatePhase2MerkleTree = async (users: IPhase2AllowList[]) => {
    const merkleTree = (_users: string[]) => {
        const leaves = _users.map((user) => hre.ethers.utils.keccak256(user));
        const merkleTree = new MerkleTree(leaves, hre.ethers.utils.keccak256, {
            sortPairs: true,
        });
        const root = merkleTree.getRoot().toString('hex');

        return { leaves, merkleTree, root };
    };

    return [
        {
            role: 0, // OG Pearls
            ...merkleTree(users[0].signers.map((s) => s.address)),
        },
        {
            role: 1, // Sushi Frens
            ...merkleTree(users[1].signers.map((s) => s.address)),
        },
        {
            role: 2, // Tapiocans
            ...merkleTree(users[2].signers.map((s) => s.address)),
        },
        {
            role: 3, // Oysters
            ...merkleTree(users[3].signers.map((s) => s.address)),
        },
    ];
};

const generatePhase3Signers = async (pcnft: ERC721Mock) => {
    const signers = await randomSigners(714);
    for (const signer of signers) {
        await pcnft.mint(signer.address);
    }
    return signers;
};

const generatePhase2Data = (role: number, merkleProof: string[]) => {
    return hre.ethers.utils.defaultAbiCoder.encode(
        ['uint256', 'bytes32[]'],
        [role, merkleProof],
    );
};

const generatePhase3Data = (tokenID: number) => {
    return hre.ethers.utils.defaultAbiCoder.encode(['uint256'], [tokenID]);
};
