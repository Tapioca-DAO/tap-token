// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'tapioca-sdk/dist/contracts/interfaces/ILayerZeroEndpoint.sol';
import 'tapioca-sdk/dist/contracts/token/oft/extension/PausableOFT.sol';
import 'tapioca-sdk/dist/contracts/libraries/LzLib.sol';
import 'prb-math/contracts/PRBMathSD59x18.sol';

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

/// @title Tapioca OFT token
/// @notice OFT compatible TAP token
/// @dev Latest size: 17.663  KiB
/// @dev Emissions calculator for DSO: https://www.desmos.com/calculator/1fa0zen2ut
contract TapOFT is PausableOFT {
    using ExcessivelySafeCall for address;
    using PRBMathSD59x18 for int256;
    using BytesLib for bytes;

    // ==========
    // *DATA*
    // ==========

    //  Allocation:
    // =========
    // * DSO: 66.5m
    // * Contributors: 15m
    // * Investors: 11m
    // * LBP: 5m
    // * Airdrop: 2.5m
    // == 100M ==
    uint256 public constant INITIAL_SUPPLY = 1e18 * 33_500_000; // Everything minus DSO

    /// @notice the a parameter used in the emission function; can be changed by governance
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    int256 public a_param = 25 * 10e17; // 29

    /// @notice the b parameter used in the emission function; can be changed by governance
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    int256 public b_param = 3561;

    /// @notice the c parameter used in the emission function; can be changed by governance
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    int256 public c_param = 34 * 10e16; // 3.4

    /// @notice seconds in a week
    uint256 public constant WEEK = 604800;

    /// @notice starts time for emissions
    /// @dev initialized in the constructor with block.timestamp
    uint256 public immutable emissionsStartTime;

    /// @notice returns the amount minted for a specific week
    /// @dev week is computed using (timestamp - emissionStartTime) / WEEK
    mapping(int256 => uint256) public mintedInWeek;

    /// @notice returns the minter address
    address public minter;

    /// @notice LayerZero governance chain identifier
    uint16 public governanceChainIdentifier;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice event emitted when a new minter is set
    event MinterUpdated(address indexed _old, address indexed _new);
    /// @notice event emitted when new TAP is minted
    event Minted(address indexed _by, address indexed _to, uint256 _amount);
    /// @notice event emitted when new TAP is burned
    event Burned(address indexed _from, uint256 _amount);
    /// @notice event emitted when mining parameters are updated
    event UpdateMiningParameters(uint256 _blockTimestmap, uint256 _rate, uint256 _startEpochSupply);
    /// @notice event emitted when the A parameter of the emission formula is updated
    event AParamUpdated(int256 _old, int256 _new);
    /// @notice event emitted when the B parameter of the emission formula is updated
    event BParamUpdated(int256 _old, int256 _new);
    /// @notice event emitted when the C parameter of the emission formula is updated
    event CParamUpdated(int256 _old, int256 _new);
    /// @notice event emitted when the governance chain identifier is updated
    event GovernanceChainIdentifierUpdated(uint16 _old, uint16 _new);

    // ==========
    // * METHODS *
    // ==========
    /// @notice Creates a new TAP OFT type token
    /// @dev The initial supply of 100M is not minted here as we have the wrap method
    /// @param _lzEndpoint the layer zero address endpoint deployed on the current chain
    /// @param _contributors address for the contributors
    /// @param _investors address for the investors
    /// @param _lbp address for the LBP
    /// @param _airdrop address for the airdrop
    /// @param _governanceChainId LayerZero governance chain identifier
    constructor(
        address _lzEndpoint,
        address _contributors,
        address _investors,
        address _lbp,
        address _airdrop,
        uint16 _governanceChainId
    ) PausableOFT('Tapioca', 'TAP', _lzEndpoint) {
        require(_lzEndpoint != address(0), 'LZ endpoint not valid');
        governanceChainIdentifier = _governanceChainId;
        if (_getChainId() == governanceChainIdentifier) {
            _mint(_contributors, 1e18 * 15_000_000);
            _mint(_investors, 1e18 * 11_000_000);
            _mint(_lbp, 1e18 * 5_000_000);
            _mint(_airdrop, 1e18 * 2_500_000);
            require(totalSupply() == INITIAL_SUPPLY, 'initial supply not valid');
        }
        emissionsStartTime = block.timestamp;
    }

    ///-- Owner methods --
    /// @notice sets the governance chain identifier
    /// @param _identifier LayerZero chain identifier
    function setGovernanceChainIdentifier(uint16 _identifier) external onlyOwner {
        emit GovernanceChainIdentifierUpdated(governanceChainIdentifier, _identifier);
        governanceChainIdentifier = _identifier;
    }

    /// @notice sets a new value for parameter
    /// @param val the new value
    function setAParam(int256 val) external onlyOwner {
        emit AParamUpdated(a_param, val);
        a_param = val;
    }

    /// @notice sets a new value for parameter
    /// @param val the new value
    function setBParam(int256 val) external onlyOwner {
        emit BParamUpdated(b_param, val);
        b_param = val;
    }

    /// @notice sets a new value for parameter
    /// @param val the new value
    function setCParam(int256 val) external onlyOwner {
        emit CParamUpdated(c_param, val);
        c_param = val;
    }

    /// @notice sets a new minter address
    /// @param _minter the new address
    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), 'address not valid');
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    //-- View methods --
    /// @notice returns token's decimals
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @notice Returns the current week given a timestamp
    function timestampToWeek(uint256 timestamp) external view returns (int256) {
        if (timestamp > block.timestamp) return 0;
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        if (timestamp < emissionsStartTime) return 0;

        return _timestampToWeek(timestamp);
    }

    /// @notice returns available emissions for a specific timestamp
    /// @param timestamp the moment in time to emit for
    function availableForWeek(uint256 timestamp) external view returns (uint256) {
        if (timestamp > block.timestamp) return 0;
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        if (timestamp < emissionsStartTime) return 0;

        int256 x = _timestampToWeek(timestamp);
        if (mintedInWeek[x] > 0) return 0;

        return uint256(_computeEmissionPerWeek(x));
    }

    ///-- Write methods --
    /// @notice returns the available emissions for a specific week
    /// @param timestamp the moment in time to emit for
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    function emitForWeek(uint256 timestamp) external whenNotPaused returns (uint256) {
        if (timestamp != 0) {
            require(emissionsStartTime < timestamp && timestamp <= block.timestamp, 'timestamp not valid');
        } else {
            timestamp = block.timestamp;
        }
        require(_getChainId() == governanceChainIdentifier, 'chain not valid');

        int256 x = _timestampToWeek(timestamp);
        if (mintedInWeek[x] > 0) return 0;

        uint256 emission = uint256(_computeEmissionPerWeek(x));
        mintedInWeek[x] = emission;

        _mint(address(this), emission);
        emit Minted(msg.sender, address(this), emission);

        return emission;
    }

    /// @notice extracts from the minted TAP
    /// @param _amount TAP amount
    function extractTAP(uint256 _amount) external whenNotPaused {
        address _minter = minter;
        require(msg.sender == _minter || msg.sender == owner(), 'unauthorized');
        require(_amount > 0, 'amount not valid');

        uint256 unclaimed = balanceOf(address(this));
        require(unclaimed >= _amount, 'exceeds allowable amount');
        _transfer(address(this), _minter, _amount);
    }

    /// @notice burns TAP
    /// @param _amount TAP amount
    function removeTAP(uint256 _amount) external whenNotPaused {
        _burn(msg.sender, _amount);
        emit Burned(msg.sender, _amount);
    }

    ///-- Internal methods --

    function _timestampToWeek(uint256 timestamp) internal view returns (int256) {
        return int256((timestamp - emissionsStartTime) / WEEK);
    }

    ///-- Private methods --
    /// @notice Return the current chain ID.
    /// @dev Useful for testing.
    function _getChainId() private view returns (uint16) {
        return uint16(ILayerZeroEndpoint(lzEndpoint).getChainId());
    }

    /// @notice returns the available emissions for a specific week
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    /// @dev constants: a = 25, b = 3561, c = 3.4
    /// @param x week number
    function _computeEmissionPerWeek(int256 x) private view returns (int256 result) {
        int256 fx = PRBMathSD59x18.fromInt(x).div(a_param);
        int256 pow = c_param - fx;
        result = ((b_param * x) * (PRBMathSD59x18.e().pow(pow)));
    }
}
