// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

contract Vesting is BoringOwnable, ReentrancyGuard {
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

    /// @notice user vesting data
    struct UserData {
        uint256 amount;
        uint256 claimed;
        uint256 latestClaimTimestamp;
        bool revoked;
    }
    mapping(address => UserData) public users;

    uint256 private _totalAmount;
    uint256 private _totalClaimed;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error NotStarted();
    error NothingToClaim();
    error Initialized();
    error AddressNotValid();
    error AmountNotValid();
    error AlreadyRegistered();
    error NoTokens();
    error NotEnough();
    error BalanceTooLow();
    error VestingDurationNotValid();

    // *************** //
    // *** EVENTS *** //
    // ************** //
    /// @notice event emitted when a new user is registered
    event UserRegistered(address indexed user, uint256 indexed amount);
    /// @notice event emitted when someone claims available tokens
    event Claimed(address indexed user, uint256 indexed amount);

    /// @notice creates a new Vesting contract
    /// @param _cliff cliff period
    /// @param _duration vesting period
    constructor(uint256 _cliff, uint256 _duration, address _owner) {
        if (_duration == 0) revert VestingDurationNotValid();

        cliff = _cliff;
        duration = _duration;
        owner = _owner;
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
    function claim() external nonReentrant {
        if (start == 0 || seeded == 0) revert NotStarted();
        uint256 _claimable = claimable(msg.sender);
        if (_claimable == 0) revert NothingToClaim();

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
        if (start > 0) revert Initialized();
        if (_user == address(0)) revert AddressNotValid();
        if (_amount == 0) revert AmountNotValid();
        if (users[_user].amount > 0) revert AlreadyRegistered();

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
    function init(IERC20 _token, uint256 _seededAmount) external onlyOwner {
        if (start > 0) revert Initialized();
        if (_seededAmount == 0) revert NoTokens();
        if (_totalAmount > _seededAmount) revert NotEnough();

        token = _token;
        uint256 availableToken = _token.balanceOf(address(this));
        if (availableToken < _seededAmount) revert BalanceTooLow();

        seeded = _seededAmount;
        start = block.timestamp;
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
