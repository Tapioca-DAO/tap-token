// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/IVeTap.sol';
import './interfaces/ILayerZeroEndpoint.sol';
import './OFT20/PausableOFT.sol';
import 'prb-math/contracts/PRBMathSD59x18.sol';

/// @title Tapioca OFT token
/// @notice OFT compatible TAP token
/// @dev Latest size: 17.663  KiB
/// @dev Emissions calculator: https://www.desmos.com/calculator/1fa0zen2ut
contract TapOFT is PausableOFT {
    using PRBMathSD59x18 for int256;

    // ==========
    // *DATA*
    // ==========

    //  Allocation:
    // =========
    // * Team: 15m
    // * Advisors: 4m
    // * DAO: 63m
    // * Seed: 8m
    // * OTC: 5m
    // * LBP: 5m
    // == 100M ==
    uint256 public constant INITIAL_SUPPLY = 1e18 * 100_000_000;
    uint256 public constant LOCK = 10;
    uint256 public constant INCREASE_AMOUNT = 11;

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

    /// @notice returns the amount minted for a specific week
    /// @dev week is computed using (timestamp - emissionStartTime) / WEEK
    mapping(int256 => uint256) public mintedInWeek;

    /// @notice returns the minter address
    address public minter;

    /// @notice returns the voting escrow address
    /// @dev veTap is deployed only on Optimism
    address public veTap;

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
    event Burned(address indexed _by, address indexed _from, uint256 _amount);
    /// @notice event emitted when mining parameters are updated
    event UpdateMiningParameters(uint256 _blockTimestmap, uint256 _rate, uint256 _startEpochSupply);
    /// @notice event emitted when the A parameter of the emission formula is updated
    event AParamUpdated(int256 _old, int256 _new);
    /// @notice event emitted when the B parameter of the emission formula is updated
    event BParamUpdated(int256 _old, int256 _new);
    /// @notice event emitted when the C parameter of the emission formula is updated
    event CParamUpdated(int256 _old, int256 _new);
    /// @notice event emitted when veTap address is updated
    event VeTapUpdated(address indexed _old, address indexed _new);
    /// @notice event emitted when TAP is locked for voting
    event VeLockedFor(address indexed forAddr, uint256 amount, uint256 time);
    /// @notice event emitted when TAP amount from veTap is increased
    event IncreasedVeAmount(address indexed forAddr, uint256 amount);
    /// @notice event emitted when the governance chain identifier is updated
    event GovernanceChainIdentifierUpdated(uint16 _old, uint16 _new);

    // ==========
    // * METHODS *
    // ==========
    /// @notice Creates a new TAP OFT type token
    /// @dev The initial supply of 100M is not minted here as we have the wrap method
    /// @param _lzEndpoint the layer zero address endpoint deployed on the current chain
    /// @param _team address for the team tokens
    /// @param _advisors address for the advisors tokens
    /// @param _dao address for the DAO tokens
    /// @param _seed address for the seed tokens
    /// @param _otc address for the OTC tokens
    /// @param _lbp address for the LBP tokens
    /// @param _governanceChainId LayerZero governance chain identifier
    constructor(
        address _lzEndpoint,
        address _team,
        address _advisors,
        address _dao,
        address _seed,
        address _otc,
        address _lbp,
        uint16 _governanceChainId
    ) PausableOFT('Tapioca', 'TAP', _lzEndpoint) {
        require(_lzEndpoint != address(0), 'LZ endpoint not valid');
        governanceChainIdentifier = _governanceChainId;
        if (_getChainId() == governanceChainIdentifier) {
            _mint(_team, 1e18 * 15_000_000);
            _mint(_advisors, 1e18 * 4_000_000);
            _mint(_dao, 1e18 * 63_000_000);
            _mint(_seed, 1e18 * 8_000_000);
            _mint(_otc, 1e18 * 5_000_000);
            _mint(_lbp, 1e18 * 5_000_000);
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

    /// @notice sets the VotingEscrow address
    /// @param addr the VotingEscrow address
    function setVeTap(address addr) external onlyOwner {
        emit VeTapUpdated(veTap, addr);
        veTap = addr;
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

    /// @notice returns available emissions for a specific timestamp
    /// @param timestamp the moment in time to emit for
    function availableForWeek(uint256 timestamp) external view returns (uint256) {
        if (timestamp > block.timestamp) return 0;
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        if (timestamp < emissionsStartTime) return 0;

        int256 x = int256((timestamp - emissionsStartTime) / WEEK);
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

        int256 x = int256((timestamp - emissionsStartTime) / WEEK);
        if (mintedInWeek[x] > 0) return 0;

        uint256 emission = uint256(_computeEmissionPerWeek(x));
        mintedInWeek[x] = emission;

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

    /// @notice lock TapOFT and get veTap on Optimism
    /// @dev cannot be called on Optimism; use VeTap directly
    /// @param _amount the amount of TAP to lock for voting power
    /// @param _time lock duration
    function getVotingPower(
        uint256 _amount,
        uint256 _time,
        uint256 _action
    ) external payable {
        require(_getChainId() != governanceChainIdentifier, 'use VeTap directly');
        require(_action == LOCK || _action == INCREASE_AMOUNT, 'action not valid');

        //debit from current chain
        bytes memory packedAddress = abi.encodePacked(msg.sender);
        _debitFrom(msg.sender, _getChainId(), packedAddress, _amount);

        //send to governance chain with the following format [receiver, amount, lock, duration]
        bytes memory payload = abi.encode(packedAddress, _amount, _action, _time);
        _lzSend(governanceChainIdentifier, payload, payable(msg.sender), address(0x0), bytes(''), msg.value);

        emit SendToChain(governanceChainIdentifier, msg.sender, packedAddress, _amount);
    }

    ///-- Internal methods --
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) internal override {
        // decode and load the toAddress
        (bytes memory toAddressBytes, uint256 amount, uint256 action, uint256 time) = abi.decode(
            _payload,
            (bytes, uint256, uint256, uint256)
        );
        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }

        if (action == LOCK) {
            _creditTo(_srcChainId, address(this), amount);
            _approve(address(this), veTap, amount);
            IVeTap(veTap).create_lock_for(toAddress, amount, time);
            emit VeLockedFor(toAddress, amount, time);
        } else if (action == INCREASE_AMOUNT) {
            _creditTo(_srcChainId, address(this), amount);
            _approve(address(this), veTap, amount);
            IVeTap(veTap).increase_amount_for(toAddress, amount);
            emit IncreasedVeAmount(toAddress, amount);
        } else {
            //credit TAP to sender, on current chain
            _creditTo(_srcChainId, toAddress, amount);
        }

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, amount);
    }

    ///-- Private methods --
    /// @notice Return the current chain ID.
    /// @dev Useful for testing.
    function _getChainId() private view returns (uint16) {
        return uint16(ILayerZeroEndpoint(lzEndpoint).getChainId());
    }

    /// @notice returns the available emissions for a specific week
    /// @dev formula: b(xe^(c-f(x))) where f(x)=x/a
    /// @dev constants: a = 24, b = 2500, c = 3.7
    /// @param x week number
    function _computeEmissionPerWeek(int256 x) private view returns (int256 result) {
        int256 fx = PRBMathSD59x18.fromInt(x).div(a_param);
        int256 pow = c_param - fx;
        result = ((b_param * x) * (PRBMathSD59x18.e().pow(pow)));
    }
}
