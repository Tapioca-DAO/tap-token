// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice the vested token
    IERC20 public token;

    /// @notice returns the start time for vesting
    uint256 public start;

    /// @notice returns the cliff period
    uint256 public immutable cliff;

    /// @notice returns total vesting duration
    uint256 public immutable duration;

    /// @notice returns total available tokens
    uint256 public seeded;

    /// @notice returns total registered amount
    uint256 public totalRegisteredAmount;

    /// @notice Used for initial unlock
    uint256 private __initialUnlockTimeOffset;

    /// @notice user vesting data
    struct UserData {
        uint256 amount;
        uint256 claimed;
        uint256 latestClaimTimestamp;
        bool revoked;
    }

    mapping(address => UserData) public users;

    uint256 private __totalClaimed;

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
    error Overflow();

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

        _transferOwnership(_owner);
    }

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice returns total claimable
    function claimable() external view returns (uint256) {
        return _vested(seeded) - __totalClaimed;
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
        return __totalClaimed;
    }

    /// @notice Compute the time needed to unlock an amount of tokens, given a total amount.
    /// @param _start The start time
    /// @param _totalAmount The total amount to be vested
    /// @param _amount The amount to be unlocked
    /// @param _duration The vesting duration
    function computeTimeFromAmount(uint256 _start, uint256 _totalAmount, uint256 _amount, uint256 _duration)
        external
        pure
        returns (uint256)
    {
        return _computeTimeFromAmount(_start, _totalAmount, _amount, _duration);
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice claim available tokens
    /// @dev claim works for msg.sender
    function claim() external nonReentrant {
        if (start == 0) revert NotStarted();
        uint256 _claimable = claimable(msg.sender);
        if (_claimable == 0) revert NothingToClaim();

        __totalClaimed += _claimable;
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
        users[_user] = data;

        totalRegisteredAmount += _amount;

        emit UserRegistered(_user, _amount);
    }

    /// @notice adds multiple users
    /// @dev should be called before init
    /// @param _users the user addresses
    /// @param _amounts user weights
    function registerUsers(address[] calldata _users, uint256[] calldata _amounts) external onlyOwner {
        if (start > 0) revert Initialized();
        if (_users.length != _amounts.length) revert("Lengths not equal");

        // Gas ops
        uint256 _totalAmount = totalRegisteredAmount;
        uint256 _cachedTotalAmount = _totalAmount;

        UserData memory data;

        uint256 len = _users.length;
        for (uint256 i; i < len;) {
            // Checks
            if (_users[i] == address(0)) revert AddressNotValid();
            if (_amounts[i] == 0) revert AmountNotValid();
            if (users[_users[i]].amount > 0) revert AlreadyRegistered();

            // Effects
            data.amount = _amounts[i];
            users[_users[i]] = data;
            emit UserRegistered(_users[i], _amounts[i]);

            _totalAmount += _amounts[i];

            unchecked {
                ++i;
            }
        }

        // Record new totals
        if (_cachedTotalAmount > _totalAmount) revert Overflow();
        totalRegisteredAmount = _totalAmount;
    }

    /// @notice init the contract with total amount.
    /// @dev If initial unlock is used, it'll compute the time needed to unlock it
    /// and subtract it from the start time, so the user can claim it immediately.
    /// @param _seededAmount total vested amount, cannot be 0.
    /// @param _initialUnlock initial unlock percentage, in BPS.
    function init(IERC20 _token, uint256 _seededAmount, uint256 _initialUnlock) external onlyOwner {
        if (start > 0) revert Initialized();
        if (_seededAmount == 0) revert NoTokens();
        if (totalRegisteredAmount > _seededAmount) revert NotEnough();

        token = _token;
        uint256 availableToken = _token.balanceOf(address(this));
        if (availableToken < _seededAmount) revert BalanceTooLow();

        seeded = _seededAmount;
        start = block.timestamp;

        if (_initialUnlock > 10_000) revert AmountNotValid();
        if (_initialUnlock > 0) {
            uint256 initialUnlockAmount = (_seededAmount * _initialUnlock) / 10_000;

            __initialUnlockTimeOffset =
                _computeTimeFromAmount(block.timestamp, _seededAmount, initialUnlockAmount, duration);
        }
    }

    /// @notice Compute the time needed to unlock an amount of tokens, given a total amount.
    /// @param _start The start time
    /// @param _totalAmount The total amount to be vested
    /// @param _amount The amount to be unlocked
    /// @param _duration The vesting duration
    function _computeTimeFromAmount(uint256 _start, uint256 _totalAmount, uint256 _amount, uint256 _duration)
        internal
        pure
        returns (uint256)
    {
        return _start - (_start - ((_amount * _duration) / _totalAmount));
    }

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //

    /// @notice Returns amount of vested tokens up to the current time
    /// @param _totalAmount The total amount to be vested
    function _vested(uint256 _totalAmount) internal view returns (uint256) {
        uint256 _cliff = cliff;
        uint256 _start = start;
        uint256 _duration = duration;

        if (_start == 0) return 0; // Not started

        if (_cliff > 0) {
            _start = _start + _cliff; // Apply cliff offset
            if (block.timestamp < _start) return 0; // Cliff not reached
        }

        if (block.timestamp >= _start - __initialUnlockTimeOffset + _duration) return _totalAmount; // Fully vested

        _start = _start - __initialUnlockTimeOffset; // Offset initial unlock so it's claimable immediately
        return (_totalAmount * (block.timestamp - _start)) / _duration; // Partially vested
    }
}
