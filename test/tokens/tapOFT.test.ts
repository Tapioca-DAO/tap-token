import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import writeJsonFile from 'write-json-file';

import {
    loadFixture,
    takeSnapshot,
} from '@nomicfoundation/hardhat-network-helpers';
import { BigNumber, BigNumberish } from 'ethers';
import { TapOFT } from '../../typechain';
import { LZEndpointMock } from '../../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';
import { setBalance } from '@nomicfoundation/hardhat-network-helpers';

import {
    BN,
    deployLZEndpointMock,
    deployTapiocaOFT,
    getERC20PermitSignature,
    randomSigners,
    time_travel,
} from '../test.utils';
import { TapiocaOFT } from 'tapioca-sdk/dist/typechain/tapiocaz';
import { token } from '../../typechain/@openzeppelin/contracts';

describe('tapOFT', () => {
    let signer: SignerWithAddress;
    let minter: SignerWithAddress;
    let normalUser: SignerWithAddress;

    let LZEndpointMockCurrentChain: LZEndpointMock;
    let LZEndpointMockGovernance: LZEndpointMock;

    let tapiocaOFT0: TapOFT;
    let tapiocaOFT1: TapOFT;

    let toft0: TapiocaOFT;
    let toft1: TapiocaOFT;

    async function register() {
        signer = (await ethers.getSigners())[0];
        minter = (await ethers.getSigners())[0];
        normalUser = (await ethers.getSigners())[2];

        const chainId = (await ethers.provider.getNetwork()).chainId;

        LZEndpointMockCurrentChain = (await deployLZEndpointMock(
            chainId,
        )) as LZEndpointMock;
        LZEndpointMockGovernance = (await deployLZEndpointMock(
            11,
        )) as LZEndpointMock;

        tapiocaOFT0 = (await deployTapiocaOFT(
            signer,
            LZEndpointMockCurrentChain.address,
            signer.address,
        )) as TapOFT;
        tapiocaOFT1 = (await deployTapiocaOFT(
            signer,
            LZEndpointMockGovernance.address,
            signer.address,
        )) as TapOFT;

        toft0 = (await deployTapiocaOFT(
            signer,
            LZEndpointMockCurrentChain.address,
            normalUser.address,
        )) as any as TapiocaOFT;
        toft1 = (await deployTapiocaOFT(
            signer,
            LZEndpointMockGovernance.address,
            normalUser.address,
        )) as any as TapiocaOFT;

        // OFT Setup
        await tapiocaOFT0.setUseCustomAdapterParams(true);
        await tapiocaOFT0.setMinDstGas(11, 870, 550_00);
        await tapiocaOFT0.setMinDstGas(11, 871, 550_00);
        await tapiocaOFT0.setMinDstGas(11, 872, 550_00);
        await tapiocaOFT0.setMinDstGas(11, 0, 200_000);

        await tapiocaOFT1.setUseCustomAdapterParams(true);
        await tapiocaOFT1.setMinDstGas(chainId, 870, 550_00);
        await tapiocaOFT1.setMinDstGas(chainId, 871, 550_00);
        await tapiocaOFT1.setMinDstGas(chainId, 872, 550_00);
        await tapiocaOFT1.setMinDstGas(chainId, 0, 200_000);

        await toft0.setUseCustomAdapterParams(true);
        await toft0.setMinDstGas(11, 0, 200_000);

        await toft1.setUseCustomAdapterParams(true);
        await toft1.setMinDstGas(chainId, 0, 200_000);

        // ---- Endpoint setup
        await LZEndpointMockCurrentChain.setDestLzEndpoint(
            tapiocaOFT1.address,
            LZEndpointMockGovernance.address,
        );
        await LZEndpointMockGovernance.setDestLzEndpoint(
            tapiocaOFT0.address,
            LZEndpointMockCurrentChain.address,
        );

        await LZEndpointMockCurrentChain.setDestLzEndpoint(
            toft1.address,
            LZEndpointMockGovernance.address,
        );
        await LZEndpointMockGovernance.setDestLzEndpoint(
            toft0.address,
            LZEndpointMockCurrentChain.address,
        );

        // ---- Trusted remote setup
        await tapiocaOFT0.setTrustedRemote(
            11,
            ethers.utils.solidityPack(
                ['address', 'address'],
                [tapiocaOFT1.address, tapiocaOFT0.address],
            ),
        );
        await tapiocaOFT1.setTrustedRemote(
            chainId,
            ethers.utils.solidityPack(
                ['address', 'address'],
                [tapiocaOFT0.address, tapiocaOFT1.address],
            ),
        );
        await tapiocaOFT0.setTrustedRemote(
            11,
            ethers.utils.solidityPack(
                ['address', 'address'],
                [tapiocaOFT1.address, tapiocaOFT0.address],
            ),
        );

        await toft0.setTrustedRemote(
            11,
            ethers.utils.solidityPack(
                ['address', 'address'],
                [toft1.address, toft0.address],
            ),
        );
        await toft0.setTrustedRemote(
            11,
            ethers.utils.solidityPack(
                ['address', 'address'],
                [toft1.address, toft0.address],
            ),
        );
        await toft1.setTrustedRemote(
            chainId,
            ethers.utils.solidityPack(
                ['address', 'address'],
                [toft0.address, toft1.address],
            ),
        );
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('Should send the correct amount of tokens to each receiver', async () => {
        const [
            _contributors,
            _earlySupporters,
            _supporters,
            _lbp,
            _dao,
            _airdrop,
        ] = (await randomSigners(6)).map((e) => e.address);

        const tapFactory = await ethers.getContractFactory('TapOFT');
        const tap = await tapFactory.deploy(
            LZEndpointMockCurrentChain.address,
            _contributors,
            _earlySupporters,
            _supporters,
            _lbp,
            _dao,
            _airdrop,
            await LZEndpointMockCurrentChain.getChainId(),
            signer.address,
        );

        const [
            balanceContributors,
            balanceEarlySupporters,
            balanceSupporters,
            balanceLBP,
            balanceDAO,
            balanceAirdrop,
        ] = await Promise.all([
            await tap.balanceOf(_contributors),
            await tap.balanceOf(_earlySupporters),
            await tap.balanceOf(_supporters),
            await tap.balanceOf(_lbp),
            await tap.balanceOf(_dao),
            await tap.balanceOf(_airdrop),
        ]);

        const pow18 = (n: any) => BN(n).mul((1e18).toString());
        expect(balanceContributors).to.be.equal(pow18(15_000_000));
        expect(balanceEarlySupporters).to.be.equal(pow18(3_686_595));
        expect(balanceSupporters).to.be.equal(pow18(12_500_000));
        expect(balanceLBP).to.be.equal(pow18(5_000_000));
        expect(balanceDAO).to.be.equal(pow18(8_000_000));
        expect(balanceAirdrop).to.be.equal(pow18(2_500_000));
    });

    describe('reverts', () => {
        it('should not burn when paused', async () => {
            const amount = BN(33_500_000).mul((1e18).toString());
            await tapiocaOFT0.updatePause(true);
            await expect(tapiocaOFT0.connect(signer).removeTAP(amount)).to.be
                .reverted;
            await tapiocaOFT0.updatePause(false);
            await expect(tapiocaOFT0.connect(signer).removeTAP(amount)).to.emit(
                tapiocaOFT0,
                'Burned',
            );
        });

        it('should not mint when paused', async () => {
            await tapiocaOFT0.setMinter(signer.address);
            await tapiocaOFT0.updatePause(true);
            await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.not.be
                .reverted;
            await expect(
                tapiocaOFT0.extractTAP(
                    signer.address,
                    await tapiocaOFT0.getCurrentWeekEmission(),
                ),
            ).to.be.reverted;

            await tapiocaOFT0.updatePause(false);
            await time_travel(604800);
            await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.emit(
                tapiocaOFT0,
                'Emitted',
            );
            const emissions = await tapiocaOFT0.getCurrentWeekEmission();
            await expect(tapiocaOFT0.extractTAP(signer.address, emissions))
                .to.emit(tapiocaOFT0, 'Minted')
                .withArgs(signer.address, signer.address, emissions);
        });

        it('should not allow emit from another chain', async () => {
            await tapiocaOFT0.setMinter(signer.address);
            const chainBLzEndpoint = await deployLZEndpointMock(11);
            const chainBTap = await deployTapiocaOFT(
                signer,
                chainBLzEndpoint.address,
                signer.address,
                10,
            );
            await chainBTap.setMinter(signer.address);
            await time_travel(7 * 86400);
            await expect(
                chainBTap.connect(signer).emitForWeek(),
            ).to.be.revertedWith('TAP: Chain not valid');
        });
        it('should not be able to deploy with an empty LayerZero endpoint', async () => {
            const factory = await ethers.getContractFactory('TapOFT');
            await expect(
                factory.deploy(
                    ethers.constants.AddressZero,
                    signer.address,
                    signer.address,
                    signer.address,
                    signer.address,
                    signer.address,
                    signer.address,
                    1,
                    signer.address,
                ),
            ).to.be.reverted;
        });
    });

    describe('emissions', () => {
        it('should emit for each week', async () => {
            await tapiocaOFT0.setMinter(signer.address);
            const initialDSOSupply = await tapiocaOFT0.dso_supply();

            const emissionForWeekBefore =
                await tapiocaOFT0.getCurrentWeekEmission();
            await tapiocaOFT0.emitForWeek();
            const emissionForWeekAfter =
                await tapiocaOFT0.getCurrentWeekEmission();
            expect(emissionForWeekAfter).to.be.gt(emissionForWeekBefore);

            await tapiocaOFT0.emitForWeek();
            expect(await tapiocaOFT0.getCurrentWeekEmission()).to.be.equal(
                emissionForWeekAfter,
            ); // Can't mint 2 times a week

            await time_travel(7 * 86400);
            await expect(tapiocaOFT0.emitForWeek()).to.emit(
                tapiocaOFT0,
                'Emitted',
            );
            expect(await tapiocaOFT0.getCurrentWeekEmission()).to.be.gt(
                emissionForWeekAfter,
            ); // Can mint after 7 days

            // DSO supply doesn't change if not extracted
            expect(await tapiocaOFT0.dso_supply()).to.be.equal(
                initialDSOSupply,
            );
        });

        it('should test weekly emissions', async () => {
            await tapiocaOFT0.setMinter(signer.address);
            const noOfWeeks = 200;
            const supplyJsonContent: any = {};
            const emissionJsonContent: any = {};
            let sum: BigNumberish = 0;
            for (let i = 1; i <= noOfWeeks; i++) {
                await time_travel(7 * 86400);
                await tapiocaOFT0.emitForWeek();
                const available =
                    await tapiocaOFT0.callStatic.getCurrentWeekEmission();
                sum = available.add(sum);
                await tapiocaOFT0.extractTAP(signer.address, available);

                supplyJsonContent[i] = ethers.utils.formatEther(sum);
                emissionJsonContent[i] = ethers.utils.formatEther(available);
            }

            await writeJsonFile(
                'test/tokens/extraSupplyPerWeek.json',
                supplyJsonContent,
            );
            await writeJsonFile(
                'test/tokens/emissionsPerWeek.json',
                emissionJsonContent,
            );
        });
    });

    describe('permit', () => {
        it('Should be able to use permit', async () => {
            const deadline =
                (await ethers.provider.getBlock('latest')).timestamp + 10_000;
            const { v, r, s } = await getERC20PermitSignature(
                signer,
                tapiocaOFT0,
                normalUser.address,
                (1e18).toString(),
                BN(deadline),
            );

            // Check if it works
            const snapshot = await takeSnapshot();
            await expect(
                tapiocaOFT0.permit(
                    signer.address,
                    normalUser.address,
                    (1e18).toString(),
                    deadline,
                    v,
                    r,
                    s,
                ),
            )
                .to.emit(tapiocaOFT0, 'Approval')
                .withArgs(
                    signer.address,
                    normalUser.address,
                    (1e18).toString(),
                );

            // Check that it can't be used twice
            await expect(
                tapiocaOFT0.permit(
                    signer.address,
                    normalUser.address,
                    (1e18).toString(),
                    deadline,
                    v,
                    r,
                    s,
                ),
            ).to.be.reverted;
            await snapshot.restore();

            // Check that it can't be used after deadline
            await time_travel(10_001);
            await expect(
                tapiocaOFT0.permit(
                    signer.address,
                    normalUser.address,
                    (1e18).toString(),
                    deadline,
                    v,
                    r,
                    s,
                ),
            ).to.be.reverted;
            await snapshot.restore();

            // Check that it can't be used with wrong signature
            const {
                v: v2,
                r: r2,
                s: s2,
            } = await getERC20PermitSignature(
                signer,
                tapiocaOFT0,
                minter.address,
                (1e18).toString(),
                BN(deadline),
            );
            await expect(
                tapiocaOFT0.permit(
                    signer.address,
                    normalUser.address,
                    (1e18).toString(),
                    deadline,
                    v2,
                    r2,
                    s2,
                ),
            ).to.be.reverted;
            await snapshot.restore();

            // Check that it can be batch called
            const permit = tapiocaOFT0.interface.encodeFunctionData('permit', [
                signer.address,
                normalUser.address,
                (1e18).toString(),
                deadline,
                v,
                r,
                s,
            ]);
            const transfer = tapiocaOFT0.interface.encodeFunctionData(
                'transferFrom',
                [signer.address, normalUser.address, (1e18).toString()],
            );

            // await expect(
            //     tapiocaOFT0.connect(normalUser).batch([permit, transfer], true),
            // )
            //     .to.emit(tapiocaOFT0, 'Transfer')
            //     .withArgs(
            //         signer.address,
            //         normalUser.address,
            //         (1e18).toString(),
            //     );
        });
    });

    describe('burn', () => {
        it('should burn', async () => {
            const toBurn = BN(10_000_000).mul((1e18).toString());
            const finalAmount = BN(36_686_595).mul((1e18).toString());

            await expect(
                tapiocaOFT0.connect(signer).setMinter(minter.address),
            ).to.emit(tapiocaOFT0, 'MinterUpdated');

            await expect(tapiocaOFT0.connect(normalUser).removeTAP(toBurn)).to
                .be.reverted;
            await expect(tapiocaOFT0.connect(signer).removeTAP(toBurn)).to.emit(
                tapiocaOFT0,
                'Burned',
            );

            const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
            expect(signerBalance).to.eq(finalAmount);

            const totalSupply = await tapiocaOFT0.totalSupply();
            expect(signerBalance).to.eq(totalSupply);
        });
    });

    describe('checks', () => {
        it('should check initial state', async () => {
            expect(await tapiocaOFT0.decimals()).eq(18);
            expect(await tapiocaOFT1.decimals()).eq(18);

            const chainId = (await ethers.provider.getNetwork()).chainId;
            expect(await LZEndpointMockCurrentChain.getChainId()).eq(chainId);
            expect(await LZEndpointMockGovernance.getChainId()).eq(11);

            expect(await tapiocaOFT0.paused()).to.be.false;
            expect(await tapiocaOFT1.paused()).to.be.false;

            const signerBalance = await tapiocaOFT0.balanceOf(signer.address);
            const totalSupply = BN(46_686_595).mul((1e18).toString());
            expect(signerBalance).to.eq(totalSupply);
        });
    });

    describe('setters', () => {
        it('should be able to set the governance chain identifier', async () => {
            await expect(
                tapiocaOFT0.connect(normalUser).setGovernanceChainIdentifier(4),
            ).to.be.reverted;
            await tapiocaOFT0.connect(signer).setGovernanceChainIdentifier(4);
        });

        it('should set minter', async () => {
            const currentMinter = await tapiocaOFT0.minter();
            await expect(
                tapiocaOFT0.connect(normalUser).setMinter(minter.address),
            ).to.be.reverted;
            await expect(
                tapiocaOFT0
                    .connect(signer)
                    .setMinter(ethers.constants.AddressZero),
            ).to.be.reverted;
            await expect(
                tapiocaOFT0.connect(signer).setMinter(minter.address),
            ).to.emit(tapiocaOFT0, 'MinterUpdated');
        });
    });

    describe('views', () => {
        it('should compute week based on timestamp correctly', async () => {
            const currentBlockTimestamp = (
                await ethers.provider.getBlock('latest')
            ).timestamp;

            expect(
                await tapiocaOFT0.timestampToWeek(currentBlockTimestamp),
            ).to.eq(0);
            for (let i = 0; i < 42; i++) {
                const week = await tapiocaOFT0.timestampToWeek(
                    (await tapiocaOFT0.WEEK())
                        .mul(i)
                        .add(currentBlockTimestamp),
                );
                expect(week).to.eq(i);
            }
        });
    });

    describe('extract', () => {
        it('should transfer unused TAP for next week', async () => {
            await tapiocaOFT0.setMinter(signer.address);
            await tapiocaOFT0.emitForWeek();
            const emissionWeek1 = await tapiocaOFT0.getCurrentWeekEmission();
            await tapiocaOFT0.extractTAP(minter.address, emissionWeek1.div(2));

            const dso_supply = await tapiocaOFT0.dso_supply();
            const toBeEmitted = dso_supply
                .sub(emissionWeek1.div(2))
                .mul(BN(8800000000000000))
                .div(BN((1e18).toString()));

            // Check emission update that accounts for unminted TAP
            await time_travel(7 * 86400);
            await tapiocaOFT0.emitForWeek();
            expect(await tapiocaOFT0.getCurrentWeekEmission()).to.be.equal(
                toBeEmitted.add(emissionWeek1.div(2)),
            );

            // Check DSO supply update
            expect(await tapiocaOFT0.dso_supply()).to.be.equal(
                dso_supply.sub(emissionWeek1.div(2)),
            );
        });
        it('should extract minted from minter', async () => {
            await tapiocaOFT0.setMinter(signer.address);
            const bigAmount = BN(33_500_000).mul((1e18).toString());
            // Check requirements
            await expect(tapiocaOFT0.connect(signer).emitForWeek()).to.emit(
                tapiocaOFT0,
                'Emitted',
            );

            await expect(
                tapiocaOFT0
                    .connect(normalUser)
                    .extractTAP(minter.address, bigAmount),
            ).to.be.revertedWith('TAP: only minter');
            await expect(
                tapiocaOFT0.connect(signer).setMinter(minter.address),
            ).to.emit(tapiocaOFT0, 'MinterUpdated');

            await expect(
                tapiocaOFT0.connect(minter).extractTAP(minter.address, 0),
            ).to.be.revertedWith('TAP: Amount not valid');
            await expect(
                tapiocaOFT0
                    .connect(minter)
                    .extractTAP(minter.address, bigAmount),
            ).to.be.revertedWith('TAP: Exceeds allowable amount');

            // Check balance
            const emissionForWeek = await tapiocaOFT0.getCurrentWeekEmission();
            const initialUserBalance = await tapiocaOFT0.balanceOf(
                minter.address,
            );
            await tapiocaOFT0
                .connect(minter)
                .extractTAP(minter.address, emissionForWeek);
            const afterExtractUserBalance = await tapiocaOFT0.balanceOf(
                minter.address,
            );
            expect(
                afterExtractUserBalance
                    .sub(initialUserBalance)
                    .eq(emissionForWeek),
            ).to.be.true;

            // Check state changes
            const currentWeek = await tapiocaOFT0.getCurrentWeek();
            const mintedInCurrentWeek = await tapiocaOFT0.mintedInWeek(
                currentWeek,
            );
            expect(mintedInCurrentWeek).to.be.equal(emissionForWeek);
        });
    });

    describe('twTAP cross-chain', () => {
        it('Should make a cross-chain twTAP participation', async () => {
            const twTAPFactory = await ethers.getContractFactory('TwTAP');
            const twTAP = await twTAPFactory.deploy(
                tapiocaOFT1.address,
                signer.address,
            );
            const amountToParticipate = (1e18).toString();

            await tapiocaOFT1.setTwTap(twTAP.address);

            const tapBefore_chain_1 = await tapiocaOFT1.balanceOf(
                signer.address,
            );

            // If call fail, credit user with TAP
            // Test with wrong epoch duration
            await expect(
                tapiocaOFT0.lockTwTapPosition(
                    signer.address,
                    amountToParticipate,
                    10,
                    11,
                    ethers.constants.AddressZero,
                    hre.ethers.utils.solidityPack(
                        ['uint16', 'uint256'],
                        [1, 550_000], // Should use ~514_227
                    ),
                    { value: (1e18).toString() },
                ),
            ).to.emit(tapiocaOFT1, 'CallFailedStr');
            expect(await tapiocaOFT1.balanceOf(signer.address)).to.be.equal(
                tapBefore_chain_1.add(amountToParticipate),
            ); // Expect to be credited

            // Real call
            hre.tracer.enabled = true;
            await expect(
                tapiocaOFT0.lockTwTapPosition(
                    signer.address,
                    amountToParticipate,
                    await twTAP.EPOCH_DURATION(),
                    11,
                    ethers.constants.AddressZero,
                    hre.ethers.utils.solidityPack(
                        ['uint16', 'uint256'],
                        [1, 550_000], // Should use ~514_227
                    ),
                    { value: (1e18).toString() },
                ),
            ).to.emit(twTAP, 'Participate');
            hre.tracer.enabled = false;
            const blockTimestamp = (await ethers.provider.getBlock('latest'))
                .timestamp;

            // Check minted twTAP
            const tokenID = await twTAP.mintedTWTap();
            expect(tokenID).to.be.equal(1);
            const owner = await twTAP.ownerOf(tokenID);
            expect(owner).to.be.equal(signer.address);

            // Check twTAP participation
            const position = await twTAP.participants(tokenID);
            expect(position.tapAmount).to.be.equal(amountToParticipate);
            expect(position.expiry).to.be.equal(
                (await twTAP.EPOCH_DURATION()).add(blockTimestamp),
            );
        });

        it('Should make a cross-chain twTAP exit', async () => {
            const twTAPFactory = await ethers.getContractFactory('TwTAP');
            const twTAP = await twTAPFactory.deploy(
                tapiocaOFT1.address,
                signer.address,
            );
            const tapBefore_chain_0 = await tapiocaOFT0.balanceOf(
                signer.address,
            );

            await tapiocaOFT1.setTwTap(twTAP.address);

            tapiocaOFT0.lockTwTapPosition(
                signer.address,
                (1e18).toString(),
                await twTAP.EPOCH_DURATION(),
                11,
                ethers.constants.AddressZero,
                hre.ethers.utils.solidityPack(
                    ['uint16', 'uint256'],
                    [1, 550_000], // Should use ~514_227
                ),
                { value: (1e18).toString() },
            );
            const tokenID = await twTAP.mintedTWTap();

            // Test too soon
            await expect(
                tapiocaOFT0.unlockTwTapPosition(
                    signer.address,
                    tokenID,
                    11,
                    ethers.constants.AddressZero,
                    hre.ethers.utils.solidityPack(
                        ['uint16', 'uint256'],
                        [1, 750_000], // Should use ~514_227 + sendBack 200_000
                    ),
                    {
                        adapterParams: hre.ethers.utils.solidityPack(
                            ['uint16', 'uint256'],
                            [1, 200_000],
                        ),
                        refundAddress: signer.address,
                        zroPaymentAddress: ethers.constants.AddressZero,
                    },
                    { value: (10e18).toString() },
                ),
            ).to.be.emit(tapiocaOFT1, 'CallFailedStr');
            expect(await tapiocaOFT1.balanceOf(signer.address)).to.be.equal(
                (await tapiocaOFT0.balanceOf(signer.address)).add(
                    (1e18).toString(),
                ),
            );

            await time_travel((await twTAP.EPOCH_DURATION()).toNumber());

            await expect(
                tapiocaOFT0.unlockTwTapPosition(
                    signer.address,
                    tokenID,
                    11,
                    ethers.constants.AddressZero,
                    hre.ethers.utils.solidityPack(
                        ['uint16', 'uint', 'uint', 'address'],
                        [2, 750_000, (1e18).toString(), tapiocaOFT1.address], // Should use ~514_227 + sendBack 200_000
                    ),
                    {
                        adapterParams: hre.ethers.utils.solidityPack(
                            ['uint16', 'uint256'],
                            [1, 200_000],
                        ),
                        refundAddress: signer.address,
                        zroPaymentAddress: ethers.constants.AddressZero,
                    },
                    { value: (10e18).toString() },
                ),
            ).to.emit(twTAP, 'ExitPosition');

            // Check TAP was transferred back
            expect(await tapiocaOFT0.balanceOf(signer.address)).to.be.equal(
                tapBefore_chain_0,
            );
        });

        it('Should make a cross-chain twTAP reward claim', async () => {
            const twTAPFactory = await ethers.getContractFactory('TwTAP');
            const twTAP = await twTAPFactory.deploy(
                tapiocaOFT1.address,
                signer.address,
            );
            const rewardToClaim = (1e18).toString();

            await tapiocaOFT1.setTwTap(twTAP.address);

            await tapiocaOFT0.lockTwTapPosition(
                signer.address,
                (1e18).toString(),
                await twTAP.EPOCH_DURATION(),
                11,
                ethers.constants.AddressZero,
                hre.ethers.utils.solidityPack(
                    ['uint16', 'uint256'],
                    [1, 550_000], // Should use ~514_227
                ),
                { value: (1e18).toString() },
            );
            const tokenID = await twTAP.mintedTWTap();
            expect(tokenID).to.be.equal(1);

            await time_travel((await twTAP.EPOCH_DURATION()).toNumber());

            // Distribute rewards
            {
                await twTAP.addRewardToken(toft1.address);
                await twTAP.advanceWeek(2);

                await toft1
                    .connect(normalUser)
                    .approve(twTAP.address, rewardToClaim);
                await twTAP
                    .connect(normalUser)
                    .distributeReward(1, rewardToClaim);
            }

            const claimable = (await twTAP.claimable(tokenID))[1];
            expect(claimable).to.be.approximately(rewardToClaim, 1);

            await expect(
                tapiocaOFT0.claimRewards(
                    signer.address,
                    1,
                    [toft1.address],
                    11,
                    ethers.constants.AddressZero,
                    hre.ethers.utils.solidityPack(
                        ['uint16', 'uint', 'uint', 'address'],
                        [2, 10_000_000, (1e18).toString(), tapiocaOFT1.address],
                    ),
                    [
                        {
                            ethValue: (1e18).toString(),
                            callParams: {
                                adapterParams: hre.ethers.utils.solidityPack(
                                    ['uint16', 'uint256'],
                                    [1, 400_000],
                                ),
                                refundAddress: signer.address,
                                zroPaymentAddress: ethers.constants.AddressZero,
                            },
                        },
                    ],
                    { value: (2e18).toString() },
                ),
            ).to.not.be.reverted;

            const removeDust = (amount: BigNumber) => {
                const dust = amount.mod(BN(10 ** (18 - 8)).toString());
                return amount.sub(dust);
            };
            // Check reward was transferred back
            expect(await toft0.balanceOf(signer.address)).to.be.eq(
                removeDust(BN(claimable)),
            );
        });
    });
});
