// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@boringcrypto/boring-solidity/contracts/BoringOwnable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';

import './TapiocaOptionLiquidityProvision.sol';
import '../interfaces/IOracle.sol';
import '../tokens/TapOFT.sol';
import './twAML.sol';
import './oTAP.sol';

// ********************************************************************************
// *******************************,                 ,******************************
// *************************                               ************************
// *********************                                       ********************
// *****************,                     @@@                     ,****************
// ***************                        @@@                        **************
// *************                    (@@@@@@@@@@@@@(                    ************
// ***********                   @@@@@@@@#@@@#@@@@@@@@                   **********
// **********                 .@@@@@      @@@      @@@@@.                 *********
// *********                 @@@@@        @@@        @@@@@                 ********
// ********                 @@@@@&        @@@         /@@@@                 *******
// *******                 &@@@@@@        @@@          #@@@&                 ******
// ******,                 @@@@@@@@,      @@@           @@@@                 ,*****
// ******                 #@@@&@@@@@@@@#  @@@           &@@@(                 *****
// ******                 %@@@%   @@@@@@@@@@@@@@@(      (@@@%                 *****
// ******                 %@@@%          %@@@@@@@@@@@@. %@@@#                 *****
// ******.                /@@@@           @@@    *@@@@@@@@@@*                .*****
// *******                 @@@@           @@@       &@@@@@@@                 ******
// *******                 /@@@@          @@@        @@@@@@/                .******
// ********                 %&&&&         @@@        &&&&&#                 *******
// *********                 *&&&&#       @@@       &&&&&,                 ********
// **********.                 %&&&&&,    &&&    ,&&&&&%                 .*********
// ************                   &&&&&&&&&&&&&&&&&&&                   ***********
// **************                     .#&&&&&&&%.                     *************
// ****************                       %%%                       ***************
// *******************                    %%%                    ******************
// **********************                                    .*********************
// ***************************                           **************************
// ************************************..     ..***********************************

struct Participation {
    bool hasParticipated;
    bool hasVotingPower;
    uint256 magnitude;
}

struct TWAMLPool {
    uint256 totalParticipants;
    uint256 averageMagnitude;
    uint256 totalWeight;
    uint256 cumulative;
}

contract TapiocaOptionBroker is Pausable, BoringOwnable, TWAML {
    TapiocaOptionLiquidityProvision public immutable tOLP;
    IOracle public immutable tapOracle;
    TapOFT public immutable tapOFT;
    OTAP public immutable oTAP;

    uint256 public immutable start = block.timestamp; // timestamp of the start of the contract
    uint256 public lastEpochUpdate; // timestamp of the last epoch update
    uint256 public epoch; // Represents the number of weeks since the start of the contract

    mapping(address => mapping(uint256 => Participation)) public participants; // user => sglAssetId => Participation
    mapping(uint256 => mapping(uint256 => bool)) public oTAPCalls; // oTAPTokenID => epoch => hasExercised

    mapping(uint256 => mapping(uint256 => uint256)) public singularityGauges; // epoch => sglAssetId => availableTAP

    /// ===== TWAML ======
    mapping(uint256 => TWAMLPool) public twAML; // sglAssetId => twAMLPool

    uint256 constant MIN_WEIGHT_FACTOR = 10; // In BPS, 0.1%
    uint256 constant dMAX = 50 * 1e4; // 5% - 50% discount
    uint256 constant dMIN = 5 * 1e4;
    uint256 constant WEEK = 7 days;

    /// =====-------======
    constructor(
        address _tOLP,
        address _oTAP,
        address _tapOFT,
        IOracle _oracle
    ) {
        tOLP = TapiocaOptionLiquidityProvision(_tOLP);
        tapOFT = TapOFT(_tapOFT);
        tapOracle = _oracle;
        oTAP = OTAP(_oTAP);
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(uint256 indexed epoch, uint256 indexed sglAssetID, uint256 totalWeight, LockPosition lock, uint256 discount);
    event EpochUpdate(uint256 indexed epoch, uint256 indexed cumulative, uint256 indexed averageMagnitude, uint256 totalParticipants);
    event ExitPosition(uint256 indexed epoch, uint256 indexed tokenId, uint256 amount);
    event NewEpoch();
    event ExerciseOption(uint256 indexed epoch, address indexed to, uint256 indexed tapTokenID, uint256 amount);

    // ==========
    //    READ
    // ==========

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in twAMl voting and mint an oTAP position
    /// @param _tOLPTokenID The tokenId of the tOLP position
    function participate(uint256 _tOLPTokenID) external returns (uint256 oTAPTokenID) {
        // Compute option parameters
        (, LockPosition memory lock) = tOLP.getLock(_tOLPTokenID);
        address participant = tOLP.ownerOf(_tOLPTokenID);
        TWAMLPool memory pool = twAML[lock.sglAssetID];

        require(tOLP.isApprovedOrOwner(msg.sender, _tOLPTokenID), 'TapiocaOptionBroker: Not approved or owner');
        require(participants[participant][lock.sglAssetID].hasParticipated == false, 'TapiocaOptionBroker: Already participating');

        uint256 magnitude = computeMagnitude(uint256(lock.lockTime), pool.cumulative);
        uint256 target = computeTarget(dMIN, dMAX, magnitude, pool.cumulative);

        // Participate in twAMl voting
        if (lock.amount >= computeMinWeight(pool.totalWeight, MIN_WEIGHT_FACTOR)) {
            pool.totalParticipants++; // Save participation
            pool.averageMagnitude = (pool.averageMagnitude + magnitude) / pool.totalParticipants; // compute new average magnitude

            // Compute and save new cumulative
            if (lock.amount > pool.cumulative) {
                pool.cumulative += pool.averageMagnitude;
            } else {
                pool.cumulative -= pool.averageMagnitude;
            }
            // Save new weight
            pool.totalWeight += lock.amount;

            twAML[lock.sglAssetID] = pool; // Save twAML participation
            emit EpochUpdate(epoch, pool.cumulative, pool.averageMagnitude, pool.totalParticipants); // Register new voting power event
        }

        // Mint oTAP position
        participants[participant][lock.sglAssetID] = Participation(true, true, magnitude);
        oTAPTokenID = oTAP.mint(participant, lock.lockTime + lock.lockDuration, uint128(target), _tOLPTokenID);
        emit Participate(epoch, lock.sglAssetID, pool.totalWeight, lock, target);
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    function exitPosition(uint256 _tOLPTokenID) external {
        (, LockPosition memory lock) = tOLP.getLock(_tOLPTokenID);
        address participant = tOLP.ownerOf(_tOLPTokenID);
        require(tOLP.isApprovedOrOwner(msg.sender, _tOLPTokenID), 'TapiocaOptionBroker: Not approved or owner');
        require(block.timestamp > lock.lockTime + lock.lockDuration, 'TapiocaOptionBroker: Lock not expired');

        Participation memory participation = participants[participant][lock.sglAssetID];
        require(participation.hasParticipated == true, 'TapiocaOptionBroker: Not participating');

        // Remove participation
        if (participation.hasVotingPower) {
            twAML[lock.sglAssetID].totalParticipants--;
            twAML[lock.sglAssetID].totalWeight -= lock.amount;
        }

        delete participants[participant][lock.sglAssetID];

        emit ExitPosition(epoch, _tOLPTokenID, lock.amount);
    }

    function exerciseOption(uint256 _oTAPTokenID) external {
        (, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        (bool isPositionActive, LockPosition memory tOLPLockPosition) = tOLP.getLock(oTAPPosition.tOLP);

        uint256 cachedEpoch = epoch;

        require(oTAP.isApprovedOrOwner(msg.sender, _oTAPTokenID), 'TapiocaOptionBroker: Not approved or owner');
        require(isPositionActive, 'TapiocaOptionBroker: Option expired');
        require(oTAPCalls[_oTAPTokenID][cachedEpoch] == false, 'TapiocaOptionBroker: Already exercised');

        oTAPCalls[_oTAPTokenID][cachedEpoch] = true; // Save exercise call of the option for this epoch

        uint256 gaugeTotalForEpoch = singularityGauges[cachedEpoch][tOLPLockPosition.sglAssetID];
        uint256 otcAmount = muldiv(tOLPLockPosition.amount, gaugeTotalForEpoch, tOLP.getTotalPoolWeight(tOLPLockPosition.sglAssetID));

        _processOTCDeal(otcAmount, oTAPPosition.discount);

        tapOFT.transfer(msg.sender, uint256(otcAmount));
        emit ExerciseOption(cachedEpoch, msg.sender, _oTAPTokenID, otcAmount);
    }

    /// @notice Start a new epoch, extract TAP from the TapOFT contract and emit it to the active singularities
    function newEpoch() external {
        require(block.timestamp >= lastEpochUpdate + WEEK, 'TapiocaOptionBroker: too soon');

        // Update epoch info
        lastEpochUpdate = block.timestamp;
        epoch++;

        uint256 epochTAP = _extractTap();
        _emitToGauges(epochTAP);

        emit NewEpoch();
    }

    // =========
    //   OWNER
    // =========

    /// @notice Claim the Broker role of the oTAP contract
    function oTAPBrokerClaim() external {
        oTAP.brokerClaim();
    }

    // ============
    //   INTERNAL
    // ============

    function _processOTCDeal(uint256 tapAmount, uint256 discount) internal {}

    /// @notice Emit TAP to the gauges equitably
    function _emitToGauges(uint256 _epochTAP) internal {
        uint256[] memory singularities = tOLP.getSingularities();
        uint256 quotaPerSingularity = _epochTAP / singularities.length;

        unchecked {
            for (uint256 i = 0; i < singularities.length; i++) {
                singularityGauges[epoch][singularities[i]] = quotaPerSingularity;
            }
        }
    }

    /// @notice Extract TAP from the TapOFT contract for the current epoch
    function _extractTap() internal returns (uint256 emissionForEpoch) {
        emissionForEpoch = tapOFT.availableForWeek(block.timestamp);
        if (emissionForEpoch == 0) {
            emissionForEpoch = tapOFT.mintedInWeek(tapOFT.timestampToWeek(block.timestamp));
        } else {
            tapOFT.emitForWeek(block.timestamp);
        }

        tapOFT.extractTAP(emissionForEpoch);
    }
}
