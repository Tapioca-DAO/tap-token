// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './OFT20/PausableOFT.sol';

/// @title Tapioca OFT token
/// @notice OFT compatible TAP token
contract TapOFT is PausableOFT {
    // ==========
    // *CONSTANTS*
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

    uint256 public constant YEAR = 86400 * 365;

    uint256 public constant INFLATION_DELAY = 86400;
    uint256 public constant RATE_REDUCTION_TIME = YEAR;
    uint256 public constant RATE_DENOMINATOR = 10**18;
    uint256 public constant INITIAL_RATE = (1e18 * 10_000) / YEAR; //TODO: compute rate
    uint256 public constant RATE_REDUCTION_COEFFICIENT = 1189207115002721024; //TODO: compute coefficient 2 ** (1/4) * 1e18

    /// @notice returns the minter address
    address public minter;

    /// @notice returns the cached minting rate
    uint256 public rate;
    /// @notice returns the current mining epoch
    int256 public miningEpoch;
    /// @notice returns the timestamp of the start epoch
    uint256 public startEpochTime;
    /// @notice returns the supply of the start epoch
    uint256 public startEpochSupply;

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

        rate = 0;
        miningEpoch = -1;
        startEpochSupply = INITIAL_SUPPLY;
        startEpochTime = block.timestamp + INFLATION_DELAY - RATE_REDUCTION_TIME;

        //todo: set trusted remote?
    }

    ///-- Onwer methods --
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

    /// @notice  returns the current number of tokens in existence (claimed or unclaimed)
    function availableSupply() external view returns (uint256) {
        return startEpochSupply + (block.timestamp - startEpochTime) * rate;
    }

    /// @notice returns the mintable amount between start and end
    /// @param start the start timestamp
    /// @param end the end timestamp
    function mintableInTimeframe(uint256 start, uint256 end) external view returns (uint256) {
        require(start <= end, 'timeframe not valid');

        uint256 toMint = 0;
        uint256 currentEpochTime = startEpochTime;
        uint256 currentRate = rate;

        // special case if end is in future (not yet minted) epoch
        if (end > currentEpochTime + RATE_REDUCTION_TIME) {
            currentEpochTime += RATE_REDUCTION_TIME;
            currentRate = (currentRate * RATE_DENOMINATOR) / RATE_REDUCTION_COEFFICIENT;
        }

        require(end <= currentEpochTime + RATE_REDUCTION_TIME, 'too far in the future');

        // TAP won't work in 1000 years. Darn!
        for (uint256 i = 0; i <= 999; i++) {
            if (end >= currentEpochTime) {
                uint256 currentEnd = end;
                if (currentEnd > currentEpochTime + RATE_REDUCTION_TIME) {
                    currentEnd = currentEpochTime + RATE_REDUCTION_TIME;
                }

                uint256 currentStart = start;
                if (currentStart >= currentEpochTime + RATE_REDUCTION_TIME) {
                    break; //we should never get here but what if...
                } else if (currentStart < currentEpochTime) {
                    currentStart = currentEpochTime;
                }

                toMint += currentRate * (currentEnd - currentStart);
                if (start >= currentEpochTime) {
                    break;
                }
            }

            currentEpochTime -= RATE_REDUCTION_TIME;
            currentRate = (currentRate * RATE_REDUCTION_COEFFICIENT) / RATE_DENOMINATOR;
            require(currentRate <= INITIAL_RATE, 'rate not valid');
        }

        return toMint;
    }

    ///-- Write methods --
    /// @notice Update mining rate and supply at the start of the epoch
    /// @dev Callable by any address, but only once per epoch
    /// @dev Total supply becomes slightly larger if this function is called late
    function updateMiningParameters() external {
        require(block.timestamp >= startEpochTime + RATE_REDUCTION_TIME, 'too early');
        _updateMiningParameters();
    }

    /// @notice Get timestamp of the current mining epoch start while simultaneously updating mining parameters
    function startEpochTimeWrite() external returns (uint256) {
        uint256 _startEpochTime = startEpochTime;
        if (block.timestamp >= _startEpochTime + RATE_REDUCTION_TIME) {
            _updateMiningParameters();
            return startEpochTime;
        }
        return _startEpochTime;
    }

    /// @notice Get timestamp of the next mining epoch start while simultaneously updating mining parameters
    function futureEpochTimeWrite() external returns (uint256) {
        uint256 _startEpochTime = startEpochTime;
        if (block.timestamp >= _startEpochTime + RATE_REDUCTION_TIME) {
            _updateMiningParameters();
            return startEpochTime + RATE_REDUCTION_TIME;
        }
        return _startEpochTime + RATE_REDUCTION_TIME;
    }

    /// @notice mints more TAP
    /// @param _to the receiver address
    /// @param _amount TAP amount
    function createTAP(address _to, uint256 _amount) external whenNotPaused {
        require(msg.sender == minter || msg.sender == owner(), 'unauthorized');
        _mint(_to, _amount);
        emit Minted(msg.sender, _to, _amount);

        //TODO: check rate reduction over time based on Tapioca's emissions rate
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

    /// @notice Update mining rate and supply at the start of the epoch
    /// @dev Any modifying mining call must also call this
    function _updateMiningParameters() private {
        uint256 _rate = rate;
        uint256 _startEpochSupply = startEpochSupply;

        startEpochTime += RATE_REDUCTION_TIME;
        miningEpoch += 1;

        if (_rate == 0) {
            _rate = INITIAL_RATE;
        } else {
            _startEpochSupply += _rate * RATE_REDUCTION_TIME;
            startEpochSupply = _startEpochSupply;
            _rate = (_rate * RATE_DENOMINATOR) / RATE_REDUCTION_COEFFICIENT;
        }

        rate = _rate;
        emit UpdateMiningParameters(block.timestamp, _rate, _startEpochSupply);
    }
}
