// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../tokens/TapOFT.sol";
import "../twAML.sol";
import "./twTAP.sol";

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
    bool hasVotingPower;
    bool divergenceForce; // 0 negative, 1 positive
    uint256 averageMagnitude;
}

struct TWAMLPool {
    uint256 totalParticipants;
    uint256 averageMagnitude;
    uint256 totalDeposited;
    uint256 cumulative;
}

contract TapiocaDAOPortal is Pausable, BoringOwnable, TWAML {
    TapOFT public immutable tapOFT;
    TWTap public immutable twTAP;

    /// ===== TWAML ======
    TWAMLPool public twAML; // sglAssetId => twAMLPool

    mapping(address => Participation) public participants; // user => Participation

    uint256 constant MIN_WEIGHT_FACTOR = 10; // In BPS, 0.1%
    uint256 constant dMAX = 100 * 1e4; // 10% - 100% voting power multiplier
    uint256 constant dMIN = 10 * 1e4;
    uint256 constant WEEK = 7 days;

    /// =====-------======
    constructor(address _tapOFT, address _twTAP, address _owner) {
        tapOFT = TapOFT(_tapOFT);
        twTAP = TWTap(_twTAP);
        owner = _owner;
    }

    // ==========
    //   EVENTS
    // ==========
    event Participate(
        address indexed participant,
        uint256 tapAmount,
        uint256 multiplier
    );
    event AMLDivergence(
        uint256 cumulative,
        uint256 averageMagnitude,
        uint256 totalParticipants
    );
    event ExitPosition(uint256 tokenId, uint256 amount);

    // ==========
    //    READ
    // ==========

    // ===========
    //    WRITE
    // ===========

    /// @notice Participate in twAMl voting and mint an oTAP position
    /// @param _participant The address of the participant
    /// @param _amount The amount of TAP to participate with
    /// @param _duration The duration of the lock
    function participate(
        address _participant,
        uint256 _amount,
        uint256 _duration
    ) external returns (uint256 twTAPTokenID) {
        // Transfer TAP to this contract
        tapOFT.transferFrom(msg.sender, address(this), _amount);

        // Copy to memory
        TWAMLPool memory pool = twAML;

        uint256 magnitude = computeMagnitude(_duration, pool.cumulative);
        bool divergenceForce;
        uint256 multiplier = computeTarget(
            dMIN,
            dMAX,
            magnitude,
            pool.cumulative
        );

        // Participate in twAMl voting
        bool hasVotingPower = _amount >=
            computeMinWeight(pool.totalDeposited, MIN_WEIGHT_FACTOR);
        if (hasVotingPower) {
            pool.totalParticipants++; // Save participation
            pool.averageMagnitude =
                (pool.averageMagnitude + magnitude) /
                pool.totalParticipants; // compute new average magnitude

            // Compute and save new cumulative
            divergenceForce = _duration > pool.cumulative;
            if (divergenceForce) {
                if (pool.cumulative > pool.averageMagnitude) {
                    pool.cumulative -= pool.averageMagnitude;
                } else {
                    pool.cumulative = 0;
                }
            } else {
                pool.cumulative += pool.averageMagnitude;
            }

            // Save new weight
            pool.totalDeposited += _amount;

            twAML = pool; // Save twAML participation
            emit AMLDivergence(
                pool.cumulative,
                pool.averageMagnitude,
                pool.totalParticipants
            ); // Register new voting power event
        }
        // Save twAML participation
        participants[_participant] = Participation(
            hasVotingPower,
            divergenceForce,
            pool.averageMagnitude
        );

        // Mint twTAP position
        twTAPTokenID = twTAP.mint(
            _participant,
            uint256(block.timestamp) + _duration,
            _amount,
            multiplier
        );
        emit Participate(_participant, _amount, multiplier);
    }

    /// @notice Exit a twAML participation and delete the voting power if existing
    /// @param _twTAPTokenID The tokenId of the twTAP position
    function exitPosition(uint256 _twTAPTokenID) external {
        require(
            twTAP.exists(_twTAPTokenID),
            "TapiocaDAOPortal: twTAP position does not exist"
        );

        // Load data
        (address _participant, TapEntry memory twTAPPosition) = twTAP
            .attributes(_twTAPTokenID);

        require(
            block.timestamp >= twTAPPosition.expiry,
            "TapiocaDAOPortal: Lock not expired"
        );

        Participation memory participation = participants[_participant];

        // Remove participation
        if (participation.hasVotingPower) {
            TWAMLPool memory pool = twAML;

            if (participation.divergenceForce) {
                if (pool.cumulative > pool.averageMagnitude) {
                    pool.cumulative -= pool.averageMagnitude;
                } else {
                    pool.cumulative = 0;
                }
            } else {
                pool.cumulative += pool.averageMagnitude;
            }

            pool.totalDeposited -= twTAPPosition.tapAmount;
            pool.totalParticipants--;

            twAML = pool; // Save twAML exit
            emit AMLDivergence(
                pool.cumulative,
                pool.averageMagnitude,
                pool.totalParticipants
            ); // Register new voting power event
        }

        // Delete participation and burn twTAP position
        delete participants[_participant];
        twTAP.burn(_twTAPTokenID);

        // Transfer position back to twTAP owner
        tapOFT.transfer(_participant, twTAPPosition.tapAmount);

        emit ExitPosition(_twTAPTokenID, twTAPPosition.tapAmount);
    }

    /// @notice Claim the portal role of the twTAP contract
    function twTAPPortalClaim() external {
        twTAP.portalClaim();
    }
}
