import hre, { ethers } from 'hardhat';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ERC20Mock, LZEndpointMock, TapOFT } from '../../typechain/';
import { VeTap } from '../../typechain/contracts/vyper/VeTap.vy';
import { GaugeController } from '../../typechain/contracts/vyper/GaugeController.vy';

import { deployLZEndpointMock, deployTapiocaOFT, deployveTapiocaNFT, BN, time_travel, deployGaugeController } from '../test.utils';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('gaugeController', () => {
    let signer: SignerWithAddress;
    let signer2: SignerWithAddress;
    let newGauge: string;
    let anotherNewGauge: string;
    let LZEndpointMock: LZEndpointMock;
    let erc20Mock: ERC20Mock;
    let tapiocaOFT: TapOFT;
    let veTapioca: VeTap;
    let gaugeController: GaugeController;
    const DAY: number = 86400;

    async function register() {
        signer = (await ethers.getSigners())[0];
        signer2 = (await ethers.getSigners())[1];
        newGauge = (await ethers.getSigners())[2].address;
        anotherNewGauge = (await ethers.getSigners())[3].address;
        const chainId = (await ethers.provider.getNetwork()).chainId;
        LZEndpointMock = (await deployLZEndpointMock(chainId)) as LZEndpointMock;
        erc20Mock = (await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy(ethers.BigNumber.from((1e18).toString()).mul(1e9))) as ERC20Mock;
        tapiocaOFT = (await deployTapiocaOFT(LZEndpointMock.address, signer.address)) as TapOFT;
        veTapioca = (await deployveTapiocaNFT(tapiocaOFT.address, 'veTapioca Token', 'veTAP', '1')) as VeTap;
        gaugeController = (await deployGaugeController(tapiocaOFT.address, veTapioca.address)) as GaugeController;
    }

    beforeEach(async () => {
        await loadFixture(register);
    });

    it('should do nothing', async () => {
        expect(1).to.eq(1);
    });

    it('should check initial state', async () => {
        const savedAdmin = await gaugeController.admin();
        expect(savedAdmin.toLowerCase()).to.eq(signer.address.toLowerCase());

        const savedToken = await gaugeController.token();
        expect(savedToken.toLowerCase()).to.eq(tapiocaOFT.address.toLowerCase());

        const savedEscrow = await gaugeController.voting_escrow();
        expect(savedEscrow.toLowerCase()).to.eq(veTapioca.address.toLowerCase());

        const timeTotal = await gaugeController.time_total();
        expect(timeTotal.gt(0)).to.be.true;
    });

    it('should transfer ownersip', async () => {
        await expect(gaugeController.connect(signer2).commit_transfer_ownership(signer2.address)).to.be.revertedWith('unauthorized');
        await gaugeController.commit_transfer_ownership(signer2.address);

        const futureAdmin = await gaugeController.future_admin();
        expect(futureAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());

        await expect(gaugeController.connect(signer2).apply_transfer_ownership()).to.be.revertedWith('unauthorized');
        await gaugeController.apply_transfer_ownership();

        const finalAdmin = await gaugeController.admin();
        expect(finalAdmin.toLowerCase()).to.eq(signer2.address.toLowerCase());
    });

    it('should add multiple gauges against the same type', async () => {
        const gaugesNo = await gaugeController.total_gauges();
        expect(gaugesNo).to.eq(0);

        await expect(gaugeController.connect(signer).add_gauge(newGauge, 1, 0)).to.be.reverted;
        await expect(gaugeController.connect(signer2).add_gauge(newGauge, 1, 0)).to.be.revertedWith('unauthorized');

        await gaugeController.add_type('Test', 0);

        const noOfGaugeTypes = await gaugeController.n_gauge_types();
        expect(noOfGaugeTypes).to.eq(1);

        const gaugeTypeName = await gaugeController.gauge_type_names(0);
        expect(gaugeTypeName).to.eq('Test');

        await gaugeController.add_gauge(newGauge, 0, 0);
        const firstGauge = await gaugeController.gauges(0);
        expect(firstGauge.toLowerCase()).to.eq(newGauge.toLowerCase());

        await gaugeController.add_gauge(anotherNewGauge, 0, 0);
        const secondGauge = await gaugeController.gauges(1);
        expect(secondGauge.toLowerCase()).to.eq(anotherNewGauge.toLowerCase());

        await time_travel(5 * 7 * DAY);

        const firstGaugeWeight = await gaugeController.get_gauge_weight(firstGauge);
        expect(firstGaugeWeight).to.eq(0);
        const secondGaugeWeight = await gaugeController.get_gauge_weight(secondGauge);
        expect(secondGaugeWeight).to.eq(0);
    });

    it('should add gauges with different weights', async () => {
        const firstGaugeInitialWeight = BN(1).mul((1e18).toString());
        const secondGaugeInitialWeight = BN(2).mul((1e18).toString());

        await gaugeController.add_type('Test', 0);
        await gaugeController.add_gauge(newGauge, 0, firstGaugeInitialWeight);
        await gaugeController.add_gauge(anotherNewGauge, 0, secondGaugeInitialWeight);

        const firstGaugeWeight = await gaugeController.get_gauge_weight(newGauge);
        expect(firstGaugeWeight.eq(firstGaugeInitialWeight)).to.be.true;

        const secondGaugeWeight = await gaugeController.get_gauge_weight(anotherNewGauge);
        expect(secondGaugeWeight.eq(secondGaugeInitialWeight)).to.be.true;

        await time_travel(5 * 7 * DAY);

        const finalFirstGaugeWeight = await gaugeController.get_gauge_weight(newGauge);
        expect(finalFirstGaugeWeight.eq(firstGaugeInitialWeight)).to.be.true;

        const finalSecondGaugeWeight = await gaugeController.get_gauge_weight(anotherNewGauge);
        expect(finalSecondGaugeWeight.eq(secondGaugeInitialWeight)).to.be.true;
    });

    it('should add different types and gauges to each', async () => {
        const firstGaugeInitialWeight = BN(1).mul((1e18).toString());
        const secondGaugeInitialWeight = BN(2).mul((1e18).toString());

        await gaugeController.add_type('Test', firstGaugeInitialWeight);
        await gaugeController.add_type('Test2', secondGaugeInitialWeight);
        await gaugeController.add_gauge(newGauge, 0, firstGaugeInitialWeight);
        await gaugeController.add_gauge(anotherNewGauge, 1, secondGaugeInitialWeight);

        const gaugeTypeName = await gaugeController.gauge_type_names(0);
        const secondGaugeTypeName = await gaugeController.gauge_type_names(1);
        expect(gaugeTypeName).to.eq('Test');
        expect(secondGaugeTypeName).to.eq('Test2');

        const firstTypeInitialWeight = await gaugeController.get_type_weight(0);
        expect(firstTypeInitialWeight.eq(firstGaugeInitialWeight)).to.be.true;

        const secondTypeInitialWeight = await gaugeController.get_type_weight(1);
        expect(secondTypeInitialWeight.eq(secondGaugeInitialWeight)).to.be.true;

        const firstGaugeWeight = await gaugeController.get_gauge_weight(newGauge);
        expect(firstGaugeWeight.eq(firstGaugeInitialWeight)).to.be.true;

        const secondGaugeWeight = await gaugeController.get_gauge_weight(anotherNewGauge);
        expect(secondGaugeWeight.eq(secondGaugeInitialWeight)).to.be.true;

        await time_travel(100 * 7 * DAY);

        const gaugeControllerInterface = await ethers.getContractAt('IGaugeController', gaugeController.address);
        await gaugeControllerInterface.gauge_relative_weight_write(newGauge);
        await gaugeControllerInterface.gauge_relative_weight_write(anotherNewGauge);

        const firstGaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(newGauge);
        const secondGaugeRelativeWeight = await gaugeControllerInterface.gauge_relative_weight(anotherNewGauge);
        expect(firstGaugeRelativeWeight.gt(0)).to.be.true;
        expect(secondGaugeRelativeWeight.gt(0)).to.be.true;
    });

    it('should check totals', async () => {
        const ownerGauge = signer.address;
        const firstGaugeInitialWeight = BN(1).mul((1e18).toString());
        const secondGaugeInitialWeight = BN(2).mul((1e18).toString());

        await gaugeController.add_type('Test', firstGaugeInitialWeight);
        await gaugeController.add_type('Test2', secondGaugeInitialWeight);
        await gaugeController.add_type('Test3', secondGaugeInitialWeight);
        await gaugeController.add_gauge(ownerGauge, 0, firstGaugeInitialWeight);
        await gaugeController.add_gauge(newGauge, 0, firstGaugeInitialWeight);
        await gaugeController.add_gauge(anotherNewGauge, 1, secondGaugeInitialWeight);

        const totalWeight = await gaugeController.get_total_weight();
        expect(totalWeight.gt(0)).to.be.true;

        const firstTypeGaugesWeight = await gaugeController.get_weights_sum_per_type(0);
        expect(firstTypeGaugesWeight.eq(secondGaugeInitialWeight)).to.be.true;

        const secondTypeGaugesWeight = await gaugeController.get_weights_sum_per_type(1);
        expect(secondTypeGaugesWeight.eq(secondGaugeInitialWeight)).to.be.true;
    });

    it('should checkpoint all gauges', async () => {
        const firstGaugeInitialWeight = BN(1).mul((1e18).toString());
        const secondGaugeInitialWeight = BN(2).mul((1e18).toString());

        await gaugeController.add_type('Test', firstGaugeInitialWeight); //not 0 so relative gauge weight can accrue over time
        await gaugeController.add_type('Test2', secondGaugeInitialWeight); //not 0 so relative gauge weight can accrue over time
        await gaugeController.add_gauge(newGauge, 0, firstGaugeInitialWeight);
        await gaugeController.add_gauge(anotherNewGauge, 1, secondGaugeInitialWeight);

        await time_travel(DAY);
        await gaugeController.checkpoint();
        let firstGaugeWeight = await gaugeController.get_gauge_weight(newGauge);
        let secondGaugeWeight = await gaugeController.get_gauge_weight(anotherNewGauge);
        expect(firstGaugeWeight.eq(firstGaugeInitialWeight)).to.be.true;
        expect(secondGaugeWeight.eq(secondGaugeInitialWeight)).to.be.true;

        await time_travel(DAY);
        await gaugeController.checkpoint();
        firstGaugeWeight = await gaugeController.get_gauge_weight(newGauge);
        expect(firstGaugeWeight.eq(firstGaugeInitialWeight)).to.be.true;

        secondGaugeWeight = await gaugeController.get_gauge_weight(anotherNewGauge);
        expect(secondGaugeWeight.eq(secondGaugeInitialWeight)).to.be.true;

        await time_travel(DAY);
        await gaugeController.checkpoint();
        firstGaugeWeight = await gaugeController.get_gauge_weight(newGauge);
        expect(firstGaugeWeight.eq(firstGaugeInitialWeight)).to.be.true;
        secondGaugeWeight = await gaugeController.get_gauge_weight(anotherNewGauge);
        expect(secondGaugeWeight.eq(secondGaugeInitialWeight)).to.be.true;
    });

    it('should cast multiple votes from different users on one of the gauges', async () => {
        const votingPower = 5000; //50%
        const badVotingPower = 10001;
        const amountToLock = BN(10000).mul((1e18).toString());
        const invalidSigner = (await ethers.getSigners())[4];
        const latestBlock = await ethers.provider.getBlock('latest');
        const unlockTime: number = 4 * 365 * DAY; //max time

        await gaugeController.add_type('Test', 0);
        await gaugeController.add_type('Test2', 0);
        await gaugeController.add_gauge(newGauge, 0, 0);
        await gaugeController.add_gauge(anotherNewGauge, 1, 0);

        await expect(gaugeController.vote_for_gauge_weights(newGauge, badVotingPower)).to.be.reverted;
        await expect(gaugeController.vote_for_gauge_weights(invalidSigner.address, votingPower)).to.be.reverted;

        await tapiocaOFT.approve(veTapioca.address, amountToLock);
        await veTapioca.create_lock(amountToLock, latestBlock.timestamp + unlockTime);

        const initialSumWeight = await gaugeController.get_weights_sum_per_type(0);
        expect(initialSumWeight.eq(0)).to.be.true;

        const lastUserVoteBefore = await gaugeController.last_user_vote(signer.address, newGauge);
        expect(lastUserVoteBefore.eq(0)).to.be.true;

        const initialOverallWeight = await gaugeController.get_total_weight();
        expect(initialOverallWeight.eq(0)).to.be.true;

        await gaugeController.checkpoint();

        const initialGaugeWeight = await gaugeController.get_gauge_weight(newGauge);
        expect(initialGaugeWeight.eq(0)).to.be.true;

        await gaugeController.vote_for_gauge_weights(newGauge, votingPower);

        const lastUserVoteAfter = await gaugeController.last_user_vote(signer.address, newGauge);
        expect(lastUserVoteAfter.gt(0)).to.be.true;

        const slopeAfterVoting = await gaugeController.vote_user_slopes(signer.address, newGauge);
        expect(slopeAfterVoting[1].eq(votingPower)).to.be.true;

        const powerUsedAfterFirstVote = await gaugeController.vote_user_power(signer.address);
        expect(powerUsedAfterFirstVote.eq(votingPower)).to.be.true;

        const gaugeWeightAfterFirstVote = await gaugeController.get_gauge_weight(newGauge);
        expect(gaugeWeightAfterFirstVote.gt(initialGaugeWeight)).to.be.true;

        await time_travel(DAY);
        //user should not be able to cast another vote before 10 days has passed
        await expect(gaugeController.vote_for_gauge_weights(newGauge, votingPower)).to.be.revertedWith('cannot vote at the moment');
        await time_travel(10 * DAY);

        await gaugeController.vote_for_gauge_weights(newGauge, votingPower * 2);
        const slopeAfterVotingAgain = await gaugeController.vote_user_slopes(signer.address, newGauge);
        expect(slopeAfterVotingAgain[1].eq(votingPower * 2)).to.be.true;

        const gaugeWeightAfterSecondVote = await gaugeController.get_gauge_weight(newGauge);
        expect(gaugeWeightAfterSecondVote.gt(gaugeWeightAfterFirstVote)).to.be.true;

        const powerUsedAfterSecondVote = await gaugeController.vote_user_power(signer.address);
        expect(powerUsedAfterSecondVote.eq(votingPower * 2)).to.be.true;

        await gaugeController.checkpoint();
        const totalWeight = await gaugeController.get_total_weight();
        expect(totalWeight.eq(0)).to.be.true; //should be 0 as type weight didn't change

        const finalTypeWeight = await gaugeController.get_weights_sum_per_type(0);
        expect(finalTypeWeight.gt(0)).to.be.true;
    });
});
