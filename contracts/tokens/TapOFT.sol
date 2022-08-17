// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './OFT20/PausableOFT.sol';
import 'prb-math/contracts/PRBMathSD59x18.sol';

/// @title Tapioca OFT token
/// @notice OFT compatible TAP token
/// @dev Latest size: 15.875 KiB
contract TapOFT is PausableOFT {
    using PRBMathSD59x18 for int256;

    // ==========
    // *DATA*
    // ==========

    //  Allocation:
    // =========
    // * team - 15M
    // * advisors - 4M
    // * global incentives - 50M
    // * initial dex liquidity - 4M
    // * seed - 10M
    // * private - 12M
    // * ido - 3M
    // * aidrop - 2M
    // == 100M ==
    uint256 public constant INITIAL_SUPPLY = 1e18 * 100_000_000;

    /// @notice returns the cached minting rate
    uint256 public rate;
    /// @notice returns the current mining epoch
    int256 public miningEpoch;
    /// @notice returns the timestamp of the start epoch
    uint256 public startEpochTime;
    /// @notice returns the supply of the start epoch
    uint256 public startEpochSupply;

    /// @notice the a parameter used in the emission function; can be changed by governance
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    int256 public a_param = 24 * 10e17; // 24

    /// @notice the b parameter used in the emission function; can be changed by governance
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    int256 public b_param = 2500;

    /// @notice the c parameter used in the emission function; can be changed by governance
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    int256 public c_param = 37 * 10e16; // 3.7

    /// @notice seconds in a week
    uint256 public constant WEEK = 604800;

    /// @notice starts time for emissions
    /// @dev initialized in the constructor with block.timestamp
    uint256 public immutable emissionsStartTime;

    /// @notice returns true/false for a specific week
    /// @dev week is computed using (timestamp - emissionStartTime) / WEEK
    mapping(int256 => bool) public weekMinted;

    /// @notice returns the minter address
    address public minter;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice event emitted when a new minter is set
    event MinterUpdated(address indexed _old, address indexed _new);
    /// @notice event emitted when new TAP is minted
    event Minted(address indexed _by, address indexed _to, uint256 _amount);
    /// @notice event emitted when new TAP is burned
    event Burned(address indexed _by, address indexed _from, uint256 _amount);
    /// @notice event emitted when mining parameters are updated
    event UpdateMiningParameters(uint256 _blockTimestmap, uint256 _rate, uint256 _startEpochSupply);
    /// @notice minted when the A parameter of the emission formula is updated
    event AParamUpdated(int256 _old, int256 _new);
    /// @notice minted when the B parameter of the emission formula is updated
    event BParamUpdated(int256 _old, int256 _new);
    /// @notice minted when the C parameter of the emission formula is updated
    event CParamUpdated(int256 _old, int256 _new);

    // ==========
    // * METHODS *
    // ==========
    /// @notice Creates a new TAP OFT type token
    /// @dev The initial supply of 100M is not minted here as we have the wrap method
    /// @param _lzEndpoint the layer zero address endpoint deployed on the current chain
    /// @param _team address for the team tokens
    /// @param _advisors address for the advisors tokens
    /// @param _globalIncentives address for the global incentives tokens
    /// @param _initialDexLiquidity address for the initial dex liquidity tokens
    /// @param _seed address for the seed tokens
    /// @param _private address for the private sale tokens
    /// @param _ido address for the ido tokens
    /// @param _airdrop address for the airdrop tokens
    constructor(
        address _lzEndpoint,
        address _team,
        address _advisors,
        address _globalIncentives,
        address _initialDexLiquidity,
        address _seed,
        address _private,
        address _ido,
        address _airdrop
    ) PausableOFT('Tapioca', 'TAP', _lzEndpoint) {
        require(_lzEndpoint != address(0), 'LZ endpoint not valid');

        _mint(_team, 1e18 * 15_000_000);
        _mint(_advisors, 1e18 * 4_000_000);
        _mint(_globalIncentives, 1e18 * 50_000_000);
        _mint(_initialDexLiquidity, 1e18 * 4_000_000);
        _mint(_seed, 1e18 * 10_000_000);
        _mint(_private, 1e18 * 12_000_000);
        _mint(_ido, 1e18 * 3_000_000);
        _mint(_airdrop, 1e18 * 2_000_000);
        require(totalSupply() == INITIAL_SUPPLY, 'initial supply not valid');

        emissionsStartTime = block.timestamp;

        // //TODO: remove below
        // rate = 0;
        // miningEpoch = -1;
        // startEpochSupply = INITIAL_SUPPLY;
        // startEpochTime = block.timestamp + INFLATION_DELAY - RATE_REDUCTION_TIME;
    }

    ///-- Onwer methods --
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

    /// @notice returns available emissions for a specific timestamp
    /// @param timestamp the moment in time to emit for
    function availableForWeek(uint256 timestamp) external view returns (uint256) {
        if (timestamp > block.timestamp) return 0;
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        if (timestamp < emissionsStartTime) return 0;

        int256 x = int256((timestamp - emissionsStartTime) / WEEK);
        if (weekMinted[x]) return 0;

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

        int256 x = int256((timestamp - emissionsStartTime) / WEEK);
        if (weekMinted[x]) return 0;

        weekMinted[x] = true;
        uint256 emission = uint256(_computeEmissionPerWeek(x));

        _mint(address(this), emission);
        emit Minted(msg.sender, address(this), emission);

        return emission;
    }

    /// @notice extracts from the minted TAP
    /// @param _to the receiver address
    /// @param _amount TAP amount
    function extractTAP(address _to, uint256 _amount) external whenNotPaused {
        require(msg.sender == minter || msg.sender == owner(), 'unauthorized');
        require(_amount > 0, 'amount not valid');

        uint256 unclaimed = balanceOf(address(this));
        require(unclaimed >= _amount, 'exceeds allowable amount');
        _transfer(address(this), _to, _amount);
    }

    /// @notice burns TAP
    /// @param _from the address to burn from
    /// @param _amount TAP amount
    function removeTAP(address _from, uint256 _amount) external whenNotPaused {
        require(msg.sender == minter || msg.sender == owner(), 'unauthorized');
        _burn(_from, _amount);
        emit Burned(msg.sender, _from, _amount);
    }

    ///-- Private methods --
    /// @notice returns the available emissions for a specific week
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    /// @dev constants: a = 24, b = 2500, c = 3.7
    /// @param x week number
    function _computeEmissionPerWeek(int256 x) private view returns (int256 result) {
        int256 fx = PRBMathSD59x18.fromInt(x).div(a_param);
        int256 pow = c_param - fx;
        result = ((b_param * x) * (PRBMathSD59x18.e().pow(pow)));
    }

    // curve governance methods.
    // TODO: remove below
    // curve governance methods.

    // uint256 public constant YEAR = 86400 * 365;

    // uint256 public constant INFLATION_DELAY = 86400;
    // uint256 public constant RATE_REDUCTION_TIME = YEAR;
    // uint256 public constant RATE_DENOMINATOR = 10**18;
    // uint256 public constant INITIAL_RATE = (1e18 * 34_600_000) / YEAR;
    // uint256 public constant RATE_REDUCTION_COEFFICIENT = 1e15 * 2358;

    // /// @notice  returns the current number of tokens in existence (claimed or unclaimed)
    // function availableSupply() public view returns (uint256) {
    //     return totalSupply();
    // }

    // /// @notice Update mining rate and supply at the start of the epoch
    // /// @dev Callable by any address, but only once per epoch
    // /// @dev Total supply becomes slightly larger if this function is called late
    // function updateMiningParameters() external {
    //     require(block.timestamp >= startEpochTime + RATE_REDUCTION_TIME, 'too early');
    //     _updateMiningParameters();
    // }

    // /// @notice Get timestamp of the current mining epoch start while simultaneously updating mining parameters
    // function startEpochTimeWrite() external returns (uint256) {
    //     uint256 _startEpochTime = startEpochTime;
    //     if (block.timestamp >= _startEpochTime + RATE_REDUCTION_TIME) {
    //         _updateMiningParameters();
    //         return startEpochTime;
    //     }
    //     return _startEpochTime;
    // }

    // /// @notice Get timestamp of the next mining epoch start while simultaneously updating mining parameters
    // function futureEpochTimeWrite() external returns (uint256) {
    //     uint256 _startEpochTime = startEpochTime;
    //     if (block.timestamp >= _startEpochTime + RATE_REDUCTION_TIME) {
    //         _updateMiningParameters();
    //         return startEpochTime + RATE_REDUCTION_TIME;
    //     }
    //     return _startEpochTime + RATE_REDUCTION_TIME;
    // }

    // /// @notice Update mining rate and supply at the start of the epoch
    // /// @dev Any modifying mining call must also call this
    // function _updateMiningParameters() private {
    //     uint256 _rate = rate;
    //     uint256 _startEpochSupply = startEpochSupply;

    //     startEpochTime += RATE_REDUCTION_TIME;
    //     miningEpoch += 1;

    //     if (_rate == 0) {
    //         _rate = INITIAL_RATE;
    //     } else {
    //         _startEpochSupply += _rate * RATE_REDUCTION_TIME;
    //         startEpochSupply = _startEpochSupply;
    //         _rate = (_rate * RATE_DENOMINATOR) / RATE_REDUCTION_COEFFICIENT;
    //     }

    //     rate = _rate;
    //     emit UpdateMiningParameters(block.timestamp, _rate, _startEpochSupply);
    // }
}
