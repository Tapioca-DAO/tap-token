// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@boringcrypto/boring-solidity/contracts/BoringOwnable.sol';

import 'hardhat/console.sol';

contract Vesting is BoringOwnable {
    using SafeERC20 for IERC20;

    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice the vested token
    IERC20 public token;

    /// @notice returns the start time for vesting
    uint256 public start;

    /// @notice returns the cliff period
    uint256 public cliff;

    /// @notice returns total vesting duration
    uint256 public duration;

    /// @notice returns total available tokens
    uint256 public seeded = 0;

    /// @notice returns the Conservator address
    address public conservator;
    /// @notice returns contract's pause state
    bool public paused = false;

    /// @notice returns contract's revoke statusF
    bool public revoked = false;

    /// @notice user vesting data
    struct UserData {
        uint256 amount;
        uint256 claimed;
        uint256 latestClaimTimestamp;
        bool revoked;
    }
    mapping(address => UserData) public users;

    /// @notice timestamp when revoked was requested
    /// @dev can be a general revoke or per user
    uint256 public revokeRequestedAt;
    /// @notice time window until revoke can be completed
    uint256 public revokeTimeWindow = 86400; //24h

    uint256 private _totalAmount;
    uint256 private _totalClaimed;

    // **************//
    // *** EVENTS *** //
    // ************** //

    /// @notice event emitted when a new user is registered
    event UserRegistered(address indexed user, uint256 amount);
    /// @notice event emitted when someone claims available tokens
    event Claimed(address indexed user, uint256 amount);
    /// @notice event emitted when conservator is updated
    event ConservatorUpdated(address indexed old, address indexed _new);
    /// @notice event emitted when pause state is updated
    event PausedUpdated(bool oldState, bool newState);
    /// @notice event emitted when the revoke action is initated
    event RevokeRequested(address indexed user, uint256 timestamp);
    /// @notice event emitted when the revoke action has been completed
    event RevokeCompleted(address indexed user, uint256 timestamp);

    // ******************//
    // *** MODIFIERS *** //
    // ***************** //
    modifier notPaused() {
        require(!paused, 'Vesting: paused');
        _;
    }

    /// @notice creates a new Vesting contract
    /// @param _token vested token
    /// @param _cliff cliff period
    /// @param _duration vesting period
    constructor(
        IERC20 _token,
        uint256 _cliff,
        uint256 _duration
    ) {
        require(_duration > 0, 'Vesting: no vesting');

        cliff = _cliff;
        duration = _duration;
        token = _token;
        conservator = msg.sender;
    }

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice returns total claimable
    function claimable() external view returns (uint256) {
        return _vested(seeded) - _totalClaimed;
    }

    /// @notice returns total claimable for user
    /// @param _user the user address
    function claimable(address _user) public view returns (uint256) {
        return _vested(users[_user].amount) - users[_user].claimed;
    }

    /// @notice returns total vested amount
    function vested() external view returns (uint256) {
        return _vested(seeded);
    }

    /// @notice returns total vested amount for user
    /// @param _user the user address
    function vested(address _user) external view returns (uint256) {
        return _vested(users[_user].amount);
    }

    /// @notice returns total claimed
    function totalClaimed() external view returns (uint256) {
        return _totalClaimed;
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //

    /// @notice claim available tokens
    /// @dev claim works for msg.sender
    function claim() external notPaused {
        require(start > 0 && seeded > 0, 'Vesting: not started');
        require(!revoked && !users[msg.sender].revoked, 'Vesting: revoked');
        uint256 _claimable = claimable(msg.sender);
        require(_claimable > 0, 'Vesting: nothing');

        _totalClaimed += _claimable;
        users[msg.sender].claimed += _claimable;
        users[msg.sender].latestClaimTimestamp = block.timestamp;

        token.safeTransfer(msg.sender, _claimable);
        emit Claimed(msg.sender, _claimable);
    }

    // *********************** //
    // *** OWNER FUNCTIONS *** //
    // *********************** //
    /// @notice adds a new user
    /// @dev should be called before init
    /// @param _user the user address
    /// @param _amount user weight
    function registerUser(address _user, uint256 _amount) external onlyOwner {
        require(!revoked, 'Vesting: revoked');
        require(start == 0, 'Vesting: initialized');
        require(_user != address(0), 'Vesting: user not valid');
        require(_amount > 0, 'Vesting: valid not valid');
        require(users[_user].amount == 0, 'Vesting: user registered');

        UserData memory data;
        data.amount = _amount;
        data.claimed = 0;
        data.revoked = false;
        data.latestClaimTimestamp = 0;
        users[_user] = data;

        _totalAmount += _amount;

        emit UserRegistered(_user, _amount);
    }

    /// @notice inits the contract with total amount
    /// @dev sets the start time to block.timestamp
    /// @param _seededAmount total vested amount
    function init(uint256 _seededAmount) external onlyOwner notPaused {
        require(!revoked, 'Vesting: revoked');
        require(start == 0, 'Vesting: initialized');
        require(_seededAmount > 0, 'Vesting: no tokens');
        require(_totalAmount <= _seededAmount, 'Vesting: not enough');

        seeded = _seededAmount;
        start = block.timestamp;
        token.safeTransferFrom(msg.sender, address(this), _seededAmount);
    }

    /// @notice creates a revoke request
    function requestEmergencyRevoke() external onlyOwner {
        require(!revoked, 'Vesting: revoked');
        require(revokeRequestedAt == 0, 'Vesting: requested');
        revokeRequestedAt = block.timestamp;
        emit RevokeRequested(address(0), block.timestamp);
    }

    /// @notice creates a revoke request for user
    function requestEmergencyRevoke(address _user) external onlyOwner {
        require(!revoked && !users[_user].revoked, 'Vesting: revoked');
        require(revokeRequestedAt == 0, 'Vesting: requested');
        revokeRequestedAt = block.timestamp;
        emit RevokeRequested(_user, block.timestamp);
    }

    /// @notice completes revoke and transfers all the remaining tokens to sender
    function emergencyRevoke() external onlyOwner {
        require(!revoked, 'Vesting: revoked');
        require(revokeRequestedAt != 0, 'Vesting: not requested');
        require(
            block.timestamp > revokeRequestedAt + revokeTimeWindow,
            'Vesting: too early'
        );
        revoked = true;
        revokeRequestedAt = 0;
        paused = true;

        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(msg.sender, balance);

        emit RevokeCompleted(address(0), block.timestamp);
    }

    /// @notice completes revoke for user and transfers all the remaining tokens to sender
    function emergencyRevoke(address _user) external onlyOwner {
        UserData memory data = users[_user];
        require(!revoked && !data.revoked, 'Vesting: revoked');
        require(revokeRequestedAt != 0, 'Vesting: not requested');
        require(
            block.timestamp > revokeRequestedAt + revokeTimeWindow,
            'Vesting: too early'
        );

        users[_user].revoked = true;
        revokeRequestedAt = 0;

        uint256 toTransfer = data.amount - data.claimed;
        token.safeTransfer(msg.sender, toTransfer);
        emit RevokeCompleted(_user, block.timestamp);
    }

    /// @notice Set the Conservator address
    /// @dev Conservator can pause the contract
    /// @param _conservator The new address
    function setConservator(address _conservator) external onlyOwner {
        require(_conservator != address(0), 'Vesting: address not valid');
        emit ConservatorUpdated(conservator, _conservator);
        conservator = _conservator;
    }

    /// @notice updates the pause state of the contract
    /// @param val the new value
    function updatePause(bool val) external {
        require(msg.sender == conservator, 'Vesting: unauthorized');
        require(val != paused, 'Vesting: same state');
        emit PausedUpdated(paused, val);
        paused = val;
    }

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //
    function _vested(uint256 _total) private view returns (uint256) {
        if (start == 0) return 0;
        uint256 total = _total;
        if (block.timestamp < start + cliff) return 0;
        if (block.timestamp >= start + duration) return total;
        return (total * (block.timestamp - start)) / duration;
    }
}
