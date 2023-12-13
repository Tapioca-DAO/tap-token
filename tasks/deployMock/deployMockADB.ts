import { keccak256 } from 'ethers/lib/utils';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import MerkleTree from 'merkletreejs';
import { TDeploymentVMContract } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { Multicall3 } from 'tapioca-sdk/dist/typechain/tapioca-periphery';
import { ERC721Mock__factory } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';
import { buildADB } from '../deployBuilds/buildADB';
import { buildAOTAP } from '../deployBuilds/buildAOTAP';
import { buildERC721Mock } from '../deployBuilds/buildERC721Mock';
import { buildERC20Mock } from '../deployBuilds/buildMockERC20';
import { buildOracleMock } from '../deployBuilds/buildOracleMock';
import { loadVM } from '../utils';

export const deployMockADB__task = async (
    taskArgs: { load?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    // Settings
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const signer = (await hre.ethers.getSigners())[0];

    const VM = await loadVM(hre, tag);

    if (taskArgs.load) {
        const data = hre.SDK.db.loadLocalDeployment(
            'default',
            String(hre.network.config.chainId),
        );
        VM.load(data);
    } else {
        // Build contracts
        VM.add(await buildAOTAP(hre, 'aoTAPMock', [signer.address]))
            .add(
                await buildERC20Mock(hre, 'TapOFTMock', [
                    'TapOFTMock',
                    'TAPM',
                    hre.ethers.BigNumber.from(10).pow(18),
                    18,
                    signer.address,
                ]),
            )
            .add(
                await buildERC721Mock(hre, 'PCNFTMock', [
                    'PCNFTMock',
                    'PCNFTMock',
                ]),
            )
            .add(
                await buildADB(
                    hre,
                    'AirdropBroker',
                    [
                        hre.ethers.constants.AddressZero, // aoTAP
                        hre.ethers.constants.AddressZero, // TapOFT
                        hre.ethers.constants.AddressZero, // PCNFT
                        signer.address,
                        signer.address,
                    ],
                    [
                        {
                            argPosition: 0,
                            deploymentName: 'aoTAPMock',
                        },
                        { argPosition: 1, deploymentName: 'TapOFTMock' },
                        { argPosition: 2, deploymentName: 'PCNFTMock' },
                    ],
                ),
            )
            .add(
                await buildOracleMock(hre, 'TapOracleMock', [
                    'TapOracleMock',
                    'TAPM',
                    hre.ethers.BigNumber.from(10).pow(17).mul(33), // 3.3
                ]),
            )
            .add(
                await buildOracleMock(hre, 'DAIOracleMock', [
                    'DAIOracleMock',
                    'DAIOracleMock',
                    hre.ethers.BigNumber.from(10).pow(18), // 1
                ]),
            )
            .add(
                await buildERC20Mock(hre, 'DAIMock', [
                    'DAIMock',
                    'DAIMock',
                    hre.ethers.BigNumber.from(10).pow(18),
                    18,
                    signer.address,
                ]),
            );

        // Add and execute
        await VM.execute(3);
        VM.save();
        await VM.verify();
    }

    const vmList = VM.list();
    // After deployment setup

    const calls: Multicall3.CallStruct[] = [
        // Build testnet related calls
        ...(await buildAfterDepSetup(hre, vmList)),
    ];

    // Execute
    console.log('[+] After deployment setup calls number: ', calls.length);
    try {
        const multicall = await VM.getMulticall();
        const tx = await (await multicall.multicall(calls)).wait(1);
        console.log(
            '[+] After deployment setup multicall Tx: ',
            tx.transactionHash,
        );
    } catch (e) {
        // If one fail, try them one by one
        for (const call of calls) {
            await (
                await signer.sendTransaction({
                    data: call.callData,
                    to: call.target,
                })
            ).wait();
        }
    }

    console.log('[+] Stack deployed! 🎉');
};

async function buildAfterDepSetup(
    hre: HardhatRuntimeEnvironment,
    deps: TDeploymentVMContract[],
): Promise<Multicall3.CallStruct[]> {
    const calls: Multicall3.CallStruct[] = [];

    /**
     * Load addresses
     */
    const tapOracleMockAddr = deps.find(
        (e) => e.name === 'TapOracleMock',
    )?.address;
    const adbAddr = deps.find((e) => e.name === 'AirdropBroker')?.address;
    const aoTAPAddr = deps.find((e) => e.name === 'aoTAPMock')?.address;
    const pcnftAddr = deps.find((e) => e.name === 'PCNFTMock')?.address;
    const daiAddr = deps.find((e) => e.name === 'DAIMock')?.address;
    const daiOracleMockAddr = deps.find(
        (e) => e.name === 'DAIOracleMock',
    )?.address;

    if (
        !tapOracleMockAddr ||
        !adbAddr ||
        !aoTAPAddr ||
        !pcnftAddr ||
        !daiAddr ||
        !daiOracleMockAddr
    ) {
        throw new Error('[-] One address not found');
    }

    /**
     * Load contracts
     */
    const adb = await hre.ethers.getContractAt('AirdropBroker', adbAddr);
    const aoTAP = await hre.ethers.getContractAt('AOTAP', aoTAPAddr);
    const pcnft = ERC721Mock__factory.connect(pcnftAddr, hre.ethers.provider);

    /**
     * Set TapOracleMock in AirdropBroker
     */

    if ((await adb.tapOracle()) !== tapOracleMockAddr) {
        console.log('[+] Setting TapOracleMock in AirdropBroker');
        await (await adb.setTapOracle(tapOracleMockAddr, '0x00')).wait(1);
    }

    /**
     * Set DAIMock as payment token
     */

    console.log('[+] Setting DAIMock as payment in AirdropBroker');
    await (
        await adb.setPaymentToken(daiAddr, daiOracleMockAddr, '0x00')
    ).wait(1);

    /**
     * Set AirdropBroker as minter for aoTAP
     */
    if ((await aoTAP.broker()) !== adbAddr) {
        console.log('[+] Setting AirdropBroker as minter for aoTAP');
        await (await adb.aoTAPBrokerClaim()).wait(1);
    }

    /**
     * Set whitelist
     */
    const whitelist = getWhiteList();
    const phase1Registrations = [];
    const phase2Registrations: string[][] = [
        [], // OG Pearls
        [], // Tapiocans
        [], // Oysters
        [], // Cassava
    ];
    const phase3Registrations = [];
    const phase4Registrations = [];
    const phase4TwTapHolders = [];

    // Prepare for registration
    console.log('[+] Processing registrations');
    for (const { address, phases, role, twTAPHolder } of whitelist) {
        // Phase 2 register by role to create merkle roots for each role
        if (phases.find((e) => e === 2) && role !== undefined) {
            phase2Registrations[role].push(address);
        }

        // Phase 3 is PCNFT check
        if (phases.find((e) => e === 3)) {
            phase3Registrations.push(address);
        }

        // If phase 1 or 4, add to list
        if (phases.find((e) => e === 1)) {
            phase1Registrations.push(address);
        }
        if (phases.find((e) => e === 4)) {
            phase4Registrations.push(address);
        }

        // If twTAP holder, add to list
        if (twTAPHolder) {
            phase4TwTapHolders.push(address);
        }
    }

    // Create registration calls
    console.log('[+] +Call queue: phase 1 registration');
    calls.push({
        target: adbAddr,
        allowFailure: false,
        callData: adb.interface.encodeFunctionData('registerUsersForPhase', [
            1,
            phase1Registrations,
            phase1Registrations.map((e) =>
                hre.ethers.BigNumber.from(1000).pow(18),
            ),
        ]),
    });
    console.log(
        '\t +',
        phase1Registrations.length,
        'addresses with 1000 TAPM eligibility',
    );

    console.log('[+] +Call queue: phase 2 registration');
    const merkleRoots = [];
    let i = 0;
    for (const addressesPerRole of phase2Registrations) {
        const leaves = addressesPerRole.map((e) => keccak256(e));
        const tree = new MerkleTree(leaves, keccak256, { sort: true });
        const rootHash = tree.getHexRoot();
        merkleRoots.push(rootHash);
        console.log(
            '\t +',
            '+Root tree for role',
            ['OG Pearls', 'Tapiocans', 'Oysters', 'Cassava'][i],
            rootHash,
        );
        i++;
    }

    calls.push({
        target: adbAddr,
        allowFailure: false,
        callData: adb.interface.encodeFunctionData('setPhase2MerkleRoots', [
            merkleRoots as [string, string, string, string],
        ]),
    });

    console.log('[+] +Call queue: phase 3 registration');
    for (const receiver of phase3Registrations) {
        calls.push({
            target: pcnftAddr,
            allowFailure: false,
            callData: pcnft.interface.encodeFunctionData('mint', [receiver]),
        });
    }
    console.log('\t +Sending', phase3Registrations.length, 'PCNFTMock');

    // Phase 4 -  holders
    console.log('[+] +Call queue: phase 4 registration - TwTAP holders');
    calls.push({
        target: adbAddr,
        allowFailure: false,
        callData: adb.interface.encodeFunctionData('registerUsersForPhase', [
            4,
            phase4TwTapHolders,
            phase4TwTapHolders.map((e) =>
                hre.ethers.BigNumber.from(1000).pow(18),
            ),
        ]),
    });
    console.log(
        '\t +',
        phase4TwTapHolders.length,
        'addresses with 1000 TAPM eligibility',
    );

    // Phase 4 - Cassava role
    console.log('[+] +Call queue: phase 4 registration - Cassava role');
    calls.push({
        target: adbAddr,
        allowFailure: false,
        callData: adb.interface.encodeFunctionData('registerUsersForPhase', [
            4,
            phase4Registrations,
            phase4Registrations.map((e) =>
                hre.ethers.BigNumber.from(1000).pow(18),
            ),
        ]),
    });
    console.log(
        '\t +',
        phase4Registrations.length,
        'addresses with 1000 TAPM eligibility',
    );

    return calls;
}

// Roles in order [OG Pearls, Tapiocans, Oysters, Cassava]
function getWhiteList(): {
    address: string;
    phases: number[];
    role?: number;
    twTAPHolder?: boolean;
}[] {
    return [
        {
            address: '0xa4a13Bc21FC2F438e121643a4eCD05B219fD023a',
            phases: [1, 2],
            role: 0,
        }, // 1,2 OG Pearls
        {
            address: '0x01E78E0D8e4D47e01E885517EF4D8CE7f439c2E3',
            phases: [1, 3],
            twTAPHolder: true,
        }, // 1,3
        {
            address: '0x0f4dFd8Dc499E8a78842F67194A1E73124c4F75A',
            phases: [1, 4],
        }, // 1,4
        {
            address: '0x9e2Df03fF3Fe0a85349CB50695e188fAFa2C73e1',
            phases: [2, 3],
            role: 1,
        }, // 2,3 Tapiocans
        {
            address: '0xaA9f53542961EC424224CF9D2D0D184e46BFaf0d',
            phases: [2, 4],
            role: 2,
        }, // 2,4 Oysters
        {
            address: '0x53587d8a2829167C88Dc93ecD88E07FD8EF70A70',
            phases: [3, 4],
        }, // 3,4
        {
            address: '0xffa095B68C2D2B4dA3a2689E82f964B0caA0790F',
            phases: [1, 2, 3],
            role: 3,
            twTAPHolder: true,
        }, // 1,2,3 Cassava
        {
            address: '0x2e244B4Fe96824C1f6d7AcBA7994f70A595d02bb',
            phases: [1, 2, 4],
            role: 1,
        }, // 1,2,4 Tapiocans
        {
            address: '0xcB26b52DeFC7aEF57e2787d53C55f14999B2D6F2',
            phases: [2, 3, 4],
            role: 2,
        }, // 2,3,4 Oysters
        {
            address: '0x1B38906242E38195A00cA63E506893E355B0ADC7',
            phases: [1, 2, 3, 4],
            role: 0,
        }, // 1,2,3,4 OG Pearls
        {
            address: '0xdb724fb6a6bbb4f15f3384bc62441c67bbe02c81',
            phases: [1, 2],
            role: 0,
            twTAPHolder: true,
        }, // 1,2 OG Pearls
        {
            address: '0x763d405278d7532548fb2804dd6a7d7943213b6d',
            phases: [1, 3],
            twTAPHolder: true,
        }, // 1,3
        {
            address: '0xc3aef76b87539387b84cffda1b93a674f126deb0',
            phases: [1, 4],
        }, // 1,4
        {
            address: '0x86c73b2e0cb8e4b1272f8daaaca0e7e8b6143be6',
            phases: [2, 3],
            role: 1,
            twTAPHolder: true,
        }, // 2,3 Tapiocans
        {
            address: '0x9e5dae0318402a7d3909a315c5a4d68e6ac081e8',
            phases: [2, 4],
            role: 2,
        }, // 2,4 Oysters
        {
            address: '0xc8059840587f6cdd3016ae728767a04e68e4e4d3',
            phases: [3, 4],
            twTAPHolder: true,
        }, // 3,4
        {
            address: '0xf337a80a09a8d893dea511693e934fe122e12139',
            phases: [1, 2, 3],
            role: 3,
        }, // 1,2,3 Cassava
        {
            address: '0xa893b4f4c0e229c53b5f6198aa9cde1c07ab835f',
            phases: [1, 2, 4],
            role: 1,
        }, // 1,2,4 Tapiocans
        {
            address: '0xfada5d75264ede73eb85b9ba36fc96dd765afd61',
            phases: [2, 3, 4],
            role: 2,
        }, // 2,3,4 Oysters
        {
            address: '0x22076fba2ea9650a028aa499d0444c4aa9af1bf8',
            phases: [1, 2, 3, 4],
            role: 0,
        }, // 1,2,3,4 OG Pearls
    ];
}
