// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

//LZ
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFTCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

// Tapioca
import {TapOFTReceiver} from "./TapOFTReceiver.sol";
import {TapOFTReceiver} from "./TapOFTReceiver.sol";
import {TwTAP} from "../../governance/twTAP.sol";
import {TapOFTSender} from "./TapOFTSender.sol";
import {BaseTapOFTv2} from "./BaseTapOFTv2.sol";

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

/// @title Tapioca OFTv2 token
/// @notice OFT compatible TAP token
/// @dev Emissions E(x)= E(x-1) - E(x-1) * D with E being total supply a x week, and D the initial decay rate
contract TapOFTV2 is ERC20Permit, TapOFTSender, TapOFTReceiver, Pausable {
    uint256 public constant INITIAL_SUPPLY = 46_686_595 * 1e18; // Everything minus DSO
    uint256 public dso_supply = 53_313_405 * 1e18; // Emission supply for DSO

    /// @notice the a parameter used in the emission function;
    uint256 constant decay_rate = 8800000000000000; // 0.88%
    uint256 constant DECAY_RATE_DECIMAL = 1e18;

    /// @notice seconds in a week
    uint256 public constant EPOCH_TIME = 1 weeks; // 604800

    /// @notice starts time for emissions
    /// @dev initialized in the constructor with block.timestamp
    uint256 public immutable emissionsStartTime;

    /// @notice returns the amount of emitted TAP for a specific week
    /// @dev week is computed using (timestamp - emissionStartTime) / WEEK
    mapping(uint256 => uint256) public emissionForWeek;

    /// @notice returns the amount minted for a specific week
    /// @dev week is computed using (timestamp - emissionStartTime) / WEEK
    mapping(uint256 => uint256) public mintedInWeek;

    /// @notice returns the minter address
    address public minter;

    /// @notice LayerZero governance chain identifier
    uint256 public governanceEid;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice event emitted when a new minter is set
    event MinterUpdated(address indexed _old, address indexed _new);
    /// @notice event emitted when a new emission is called
    event Emitted(uint256 indexed week, uint256 indexed amount);
    /// @notice event emitted when new TAP is minted
    event Minted(
        address indexed _by,
        address indexed _to,
        uint256 indexed _amount
    );
    /// @notice event emitted when new TAP is burned
    event Burned(address indexed _from, uint256 indexed _amount);
    /// @notice event emitted when the governance chain identifier is updated
    event GovernanceChainIdentifierUpdated(
        uint256 indexed _old,
        uint256 indexed _new
    );
    /// @notice event emitted when pause state is changed
    event PausedUpdated(bool indexed oldState, bool indexed newState);
    event BoostedTAP(uint256 indexed _amount);

    // ==========
    // *ERRORS*
    // ==========
    error AddressWrong();
    error SupplyNotValid(); // Initial supply is not valid
    error AllowanceNotValid();
    error OnlyMinter();
    error TwTapAlreadySet();

    // ===========
    // *MODIFIERS*
    // ===========
    modifier onlyMinter() {
        if (msg.sender != minter) revert OnlyMinter();
        _;
    }

    modifier onlyHostChain() {
        if (_getChainId() != governanceEid) revert OnlyHostChain();
        _;
    }

    /**
     * @notice Creates a new TAP OFT type token
     * @dev The initial supply of 100M is not minted here as we have the wrap method
     *
     * Allocation:
     * ============
     * DSO: 53,313,405
     * DAO: 8m
     * Contributors: 15m
     * Early supporters: 3,686,595
     * Supporters: 12.5m
     * LBP: 5m
     * Airdrop: 2.5m
     * == 100M ==
     *
     * @param _endpoint The layer zero address endpoint deployed on the current chain.
     * @param _contributors Address of the  contributors. 15m TAP.
     * @param _earlySupporters Address of early supporters. 3,686,595 TAP.
     * @param _supporters Address of supporters. 12.5m TAP.
     * @param _lbp Address of the LBP. 5m TAP.
     * @param _dao Address of the DAO. 8m TAP.
     * @param _airdrop Address of the airdrop contract. 2.5m TAP.
     * @param _governanceEid Governance chain endpoint ID. Should be EID of the twTAP chain.
     * @param _owner Address of the conservator/owner.
     */

    constructor(
        address _endpoint,
        address _contributors,
        address _earlySupporters,
        address _supporters,
        address _lbp,
        address _dao,
        address _airdrop,
        uint256 _governanceEid,
        address _owner
    ) BaseTapOFTv2(_endpoint, _owner) ERC20Permit("TapOFT") {
        if (_endpoint == address(0)) revert AddressWrong();
        governanceEid = _governanceEid;

        // Mint only on the governance chain
        if (_getChainId() == _governanceEid) {
            _mint(_contributors, 1e18 * 15_000_000);
            _mint(_earlySupporters, 1e18 * 3_686_595);
            _mint(_supporters, 1e18 * 12_500_000);
            _mint(_lbp, 1e18 * 5_000_000);
            _mint(_dao, 1e18 * 8_000_000);
            _mint(_airdrop, 1e18 * 2_500_000);
            if (totalSupply() != INITIAL_SUPPLY) revert SupplyNotValid();
        }
        emissionsStartTime = block.timestamp;
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, // @dev unused in the default implementation.
        bytes calldata _extraData // @dev unused in the default implementation.
    ) internal virtual override(OFTCore, TapOFTReceiver) {
        return
            TapOFTReceiver._lzReceive(
                _origin,
                _guid,
                _message,
                _executor,
                _extraData
            );
    }

    /**
     * @notice set the twTAP address, can be done only once.
     */
    function setTwTAP(
        address _twTap
    ) external override onlyOwner onlyHostChain {
        if (address(twTap) != address(0)) {
            revert TwTapAlreadySet();
        }
        twTap = TwTAP(_twTap);
    }

    /**
     * @notice Return the current chain EID.
     */
    function _getChainId() internal view override returns (uint32) {
        return IMessagingChannel(endpoint).eid();
    }
}
