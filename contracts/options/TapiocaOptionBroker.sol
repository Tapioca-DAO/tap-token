// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@boringcrypto/boring-solidity/contracts/BoringOwnable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';

import './TapiocaOptionLiquidityProvision.sol';
import '../tokens/TapOFT.sol';
import './twAML.sol';
import './oTAP.sol';

//
//                 .(%%%%%%%%%%%%*       *
//             #%%%%%%%%%%%%%%%%%%%%*  ####*
//          #%%%%%%%%%%%%%%%%%%%%%#  /####
//       ,%%%%%%%%%%%%%%%%%%%%%%%   ####.  %
//                                #####
//                              #####
//   #####%#####              *####*  ####%#####*
//  (#########(              #####     ##########.
//  ##########             #####.      .##########
//                       ,####/
//                      #####
//  %%%%%%%%%%        (####.           *%%%%%%%%%#
//  .%%%%%%%%%%     *####(            .%%%%%%%%%%
//   *%%%%%%%%%%   #####             #%%%%%%%%%%
//               (####.
//      ,((((  ,####(          /(((((((((((((
//        *,  #####  ,(((((((((((((((((((((
//          (####   ((((((((((((((((((((/
//         ####*  (((((((((((((((((((
//                     ,**//*,.

struct Participation {
    bool hasParticipated;
    bool hasVotingPower;
    uint256 magnitude;
}

contract TapiocaOptionBroker is Pausable, BoringOwnable, TWAML {
    TapiocaOptionLiquidityProvision public immutable tOLP;
    OTAP public immutable oTAP;
    TapOFT public immutable tapOFT;

    uint256 public epoch; // Represents the number of weeks since the start of the contract
    uint256 constant WEEK = 7 days;

    mapping(address => mapping(uint256 => Participation)) public participants; // user => sglAssetId => Participation
    mapping(uint256 => mapping(uint256 => bool)) public oTAPCalls; // oTAPTokenID => epoch => hasExercised

    /// ===== TWAML ======
    uint256 constant dMIN = 5 * 1e4;
    uint256 constant dMAX = 50 * 1e4; // 5% - 50% discount
    uint256 constant MIN_WEIGHT_FACTOR = 10; // 0.1%

    uint256 public cumulative;
    uint256 public averageMagnitude;
    uint256 public totalParticipants;
    uint256 public totalWeight;

    /// =====-------======
    constructor(
        address _tOLP,
        address _oTAP,
        address _tapOFT
    ) {
        tOLP = TapiocaOptionLiquidityProvision(_tOLP);
        tapOFT = TapOFT(_tapOFT);
        oTAP = OTAP(_oTAP);
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(uint256 indexed epoch, uint256 indexed sglAssetID, uint256 totalWeight, LockPosition lock, uint256 discount);
    event EpochUpdate(uint256 indexed epoch, uint256 indexed cumulative, uint256 indexed averageMagnitude, uint256 totalParticipants);
    event ExitPosition(uint256 indexed epoch, uint256 indexed tokenId, uint256 amount);

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

        require(tOLP.isApprovedOrOwner(msg.sender, _tOLPTokenID), 'TapiocaOptionBroker: Not approved or owner');
        require(participants[participant][lock.sglAssetID].hasParticipated == false, 'TapiocaOptionBroker: Already participating');

        uint256 cachedCumulative = cumulative;
        uint256 magnitude = computeMagnitude(uint256(lock.lockTime), cachedCumulative);
        uint256 target = computeTarget(dMIN, dMAX, magnitude, cachedCumulative);

        // Participate in twAMl voting
        uint256 cachedTotalWeight = totalWeight;
        if (lock.amount >= computeMinWeight(cachedTotalWeight, MIN_WEIGHT_FACTOR)) {
            totalParticipants++; // Save participation

            uint256 aM = averageMagnitude; // Load average magnitude
            aM = (aM + magnitude) / totalParticipants; // compute new average magnitude
            averageMagnitude = aM; // Save new average magnitude

            // Compute and save new cumulative
            if (lock.amount > cachedCumulative) {
                cumulative += aM;
            } else {
                cumulative -= aM;
            }
            // Save new weight
            totalWeight += lock.amount;

            emit EpochUpdate(epoch, cumulative, averageMagnitude, totalParticipants); // Register new voting power event
        }

        // Mint oTAP position
        participants[participant][lock.sglAssetID] = Participation(true, true, magnitude);
        oTAPTokenID = oTAP.mint(participant, lock.lockTime + lock.lockDuration, uint128(target));
        emit Participate(epoch, lock.sglAssetID, cachedTotalWeight, lock, target);
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    function exitPosition(uint256 _tOLPTokenID) external {
        (, LockPosition memory lock) = tOLP.getLock(_tOLPTokenID);
        address participant = tOLP.ownerOf(_tOLPTokenID);
        require(tOLP.isApprovedOrOwner(msg.sender, _tOLPTokenID), 'TapiocaOptionBroker: Not approved or owner');

        Participation memory participation = participants[participant][lock.sglAssetID];
        require(participation.hasParticipated == true, 'TapiocaOptionBroker: Not participating');

        // Remove participation
        if (participation.hasVotingPower) {
            totalParticipants--;
            totalWeight -= lock.amount;
        }

        delete participants[participant][lock.sglAssetID];

        emit ExitPosition(epoch, _tOLPTokenID, lock.amount);
    }

    function exerciseOption(uint256 _oTAPTokenID) external {
        (, TapOption memory oTAPPosition) = oTAP.attributes(_oTAPTokenID);
        require(oTAP.isApprovedOrOwner(msg.sender, _oTAPTokenID), 'TapiocaOptionBroker: Not approved or owner');
        require(oTAPPosition.expiry > block.timestamp, 'TapiocaOptionBroker: Option expired');

        oTAPCalls[_oTAPTokenID][epoch] = true;
    }

    // =========
    //   OWNER
    // =========

    // ============
    //   INTERNAL
    // ============
}
