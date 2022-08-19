// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import 'hardhat/console.sol';

contract TimedGauge is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==========
    // *DATA*
    // ==========

    /// @notice returns the receipt token allowed for deposits
    address public immutable token;

    /// @notice returns reward token
    /// @dev it should be the TAP token
    address public immutable reward;

    /// @notice rewards per second
    uint256 public rewardRate = 0;

    /// @notice last reward update timestamp
    uint256 public lastUpdateTime;

    /// @notice reward-token share
    uint256 public rewardPerTokenStored;

    /// @notice returns contract's end time
    /// @dev gets increased by 'rewardsDuration' everytime new rewards are added
    uint256 public periodFinish;

    /// @notice returns the timespan when rewards are to be distributed
    uint256 public rewardsDuration = 4 * 365 days;

    /// @notice rewards paid to users so far
    mapping(address => uint256) public userRewardPerTokenPaid;

    /// @notice accrued rewards per gauge user
    mapping(address => uint256) public rewards;

    /// @notice total supply of the contract
    uint256 private _totalSupply;

    /// @notice balances per gauge user
    mapping(address => uint256) private _balances;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice event emitted when some random tokens are withdrawn from the contract
    event EmergencySave(address indexed token, uint256 amount);
    /// @notice event emitted when the rewards duration was updated
    event RewardsDurationUpdated(uint256 newDuration);
    /// @notice event emitted when new rewards were added to the pool
    event RewardAdded(uint256 reward);
    /// @notice event emitted when user deposited
    event Deposited(address indexed user, uint256 amount);
    /// @notice event emitted when user withdrawn
    event Withdrawn(address indexed user, uint256 amount);
    /// @notice event emitted when user claimed rewards
    event Claimed(address indexed user, uint256 reward);

    // ==========
    // * METHODS *
    // ==========
    /// @notice creates a new TimedGauge
    constructor(address _token, address _reward) {
        require(_token != address(0), 'token not valid');
        require(_reward != address(0), 'reward token not valid');

        token = _token;
        reward = _reward;
        periodFinish = block.timestamp + rewardsDuration;
        _pause();
    }

    ///-- Onwer methods --
    /// @notice pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice saves tokens from contract
    /// @param _token token's address
    /// @param _amount amount to be saved
    function emergencySave(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(token), 'unauthorized');
        require(_amount > 0, 'amount not valid');
        IERC20(_token).safeTransfer(owner(), _amount);
        emit EmergencySave(_token, _amount);
    }

    /// @notice updates rewards duration with a new value
    /// @param _rewardsDuration the new timestamp
    function updateRewardDuration(uint256 _rewardsDuration) external onlyOwner {
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /// @notice adds more rewards to the contract
    /// @param _amount new rewards amount
    function addRewards(uint256 _amount) external onlyOwner updateReward(address(0)) {
        require(rewardsDuration > 0, 'reward duration not set');
        if (block.timestamp >= periodFinish) {
            rewardRate = _amount / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_amount + leftover) / rewardsDuration;
        }

        IERC20(reward).safeTransferFrom(msg.sender, address(this), _amount);

        // prevent overflows
        uint256 balance = IERC20(reward).balanceOf(address(this));
        require(rewardRate <= (balance / rewardsDuration), 'reward rate not valid');

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(_amount);
    }

    ///-- View methods --
    /// @notice returns the total deposited token supply
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice returns total invested amount for an user
    /// @param _of user address
    function balanceOf(address _of) external view returns (uint256) {
        return _balances[_of];
    }

    /// @notice returns the last time rewards were applicable
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice returns rewards per deposited token
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    /// @notice rewards accrued rewards for user
    /// @param _user user's address
    function earned(address _user) public view returns (uint256) {
        return ((_balances[_user] * (rewardPerToken() - userRewardPerTokenPaid[_user])) / 1e18) + rewards[_user];
    }

    /// @notice returns reward amount for a specific time range
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    ///-- Write methods --
    /// @notice locks token into the gauge
    /// @dev updates user's rewards
    /// @param _amount deposited amount
    function deposit(uint256 _amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(_amount > 0, 'amount not valid');

        _totalSupply += _amount;
        _balances[msg.sender] += _amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(msg.sender, _amount);
    }

    /// @notice withdraws from the gauge
    /// @dev updates user's rewards
    /// @param _amount amount to withdraw
    function withdraw(uint256 _amount) public nonReentrant updateReward(msg.sender) {
        require(_amount > 0, 'amount not valid');
        _withdraw(_amount);
    }

    /// @notice claims rewards for msg.sender
    /// @dev updates user's rewards
    function claimRewards() public nonReentrant whenNotPaused updateReward(msg.sender) {
        _claim();
    }

    /// @notice withdraws the entire investment and claims rewards
    /// @dev updates user's rewards
    function exit() external nonReentrant whenNotPaused updateReward(msg.sender) {
        _withdraw(_balances[msg.sender]);
        _claim();
    }

    // @dev renounce ownership override to avoid losing contract's ownership
    function renounceOwnership() public pure override {
        revert('unauthorized');
    }

    ///-- Internal methods --
    function _claim() internal {
        uint256 _rewards = rewards[msg.sender];
        if (_rewards > 0) {
            rewards[msg.sender] = 0;
            IERC20(reward).safeTransfer(msg.sender, _rewards);
            emit Claimed(msg.sender, _rewards);
        }
    }

    function _withdraw(uint256 _amount) internal {
        _totalSupply -= _amount;
        _balances[msg.sender] = _balances[msg.sender] - _amount;
        IERC20(token).safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    // -- Modifiers --
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
}
