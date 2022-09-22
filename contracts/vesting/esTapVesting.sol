// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import '../tokens/OFT20/interfaces/IEsTapOFT.sol';

// solhint-disable max-line-length

/// @title esTAP <> TAP vesting contract
/// @dev necessary TAP balance is sent by FeeDistributor when community claims esTAP shares
///      esTAP-TAP flow:
///         - Admin constantly queues new rewards to the FeeDistributor
///         - When user claims fees from FeeDistributor, FeeDistributor mints esTAP to the user and sends TAP to esTapVesting (this contract)
///         - When user claims from esTapVesting (this contract), esTAP is burned and TAP is sent to the user
contract esTapVesting is Ownable {
    using SafeERC20 for IERC20;

    // ==========
    // *DATA*
    // ==========
    address public immutable tapToken;
    address public immutable esTapToken;

    uint256 public vestingDuration;
    struct Vesting {
        uint256 start; //vesting start
        uint256 end; //vesting end
        uint256 released; //TAP amount released for current active vesting
        uint256 esTapLocked; //total esTAP locked for vesting
        //total amounts from 1 or multiple vesting schedules
        uint256 totalBurned;
        uint256 totalEarned;
    }

    mapping(address => Vesting) public vestingData;
    mapping(address => bool) public blacklisted;

    uint256 public burnableTap;
    uint256 public usedTap;
    bool public paused;

    // ==========
    // *EVENTS*
    // ==========
    event Claimed(address indexed by, uint256 _claimedAmount, uint256 _burnedAmount, bool _forced);
    event Vested(address indexed from, address indexed _for, uint256 _lockedAmount, uint256 _totalLocked);
    event Blacklisted(address indexed addr, bool blacklist);
    event VestingDurationUpdated(uint256 _old, uint256 _new);
    event EmergencyTapWithdrawal(uint256 _amount, bool _onlyUnused, uint256 totalBefore);
    event PauseChanged(bool _old, bool _new);

    // ==========
    // * METHODS *
    // ==========
    constructor(address _tap, address _esTap) {
        require(_tap != address(0), 'TAP token not valid');
        require(_esTap != address(0), 'esTAP token not valid');

        paused = false;
        tapToken = _tap;
        esTapToken = _esTap;
        vestingDuration = 90 days;
    }

    //-- View methods --
    /// @notice returns Vesting data for account
    /// @param _for address to extract vesting data for
    function getVesting(address _for) external view returns (Vesting memory) {
        return vestingData[_for];
    }

    /// @notice returns TAP claimable amount
    /// @param  _for address to check extractable amount
    function claimableAmount(address _for) public view returns (uint256) {
        if (vestingData[_for].esTapLocked == 0) return 0;
        Vesting memory _vestingData = vestingData[_for];

        if (block.timestamp >= _vestingData.end) {
            return _vestingData.esTapLocked - _vestingData.released;
        }
        uint256 duration = _vestingData.end - _vestingData.start;
        return ((_vestingData.esTapLocked * (block.timestamp - _vestingData.start)) / duration) - _vestingData.released;
    }

    //-- Write methods --
    /// @notice creates or updates vesting schedules for someone else
    /// @dev also claims unlocked amount so far
    /// @param _esTapAmount esTAP amount to lock
    /// @param _for receiver address
    function vestFor(uint256 _esTapAmount, address _for) external whenNotPaused {
        require(!blacklisted[msg.sender], 'sender is blacklisted');
        require(!blacklisted[_for], 'receiver is blacklisted');

        // claim existing
        _claim(_for);

        // add more
        _vest(_esTapAmount, msg.sender, _for);

        emit Vested(msg.sender, _for, _esTapAmount, vestingData[_for].totalBurned + _esTapAmount);
    }

    /// @notice creates or updates vesting schedules
    /// @dev also claims unlocked amount so far
    /// @param _esTapAmount esTAP amount to lock
    function vest(uint256 _esTapAmount) external whenNotPaused {
        require(!blacklisted[msg.sender], 'blacklisted');

        // claim existing
        _claim(msg.sender);

        // add more
        _vest(_esTapAmount, msg.sender, msg.sender);
        emit Vested(msg.sender, msg.sender, _esTapAmount, vestingData[msg.sender].totalBurned + _esTapAmount);
    }

    /// @notice claims unlocked amount so far
    function claim() external whenNotPaused returns (uint256 claimable) {
        claimable = _claim(msg.sender);
        emit Claimed(msg.sender, claimable, claimable, false);
    }

    /// claims unlocked so far and slashes 50% of the remaining in exchange of the early withdraw
    /// @dev slashes 50% of the remaining amounts for claiming everything
    function forceClaim() external whenNotPaused returns (uint256 claimedFromVesting, uint256 forceClaimed) {
        //first add claimable
        claimedFromVesting = claimableAmount(msg.sender);
        uint256 toSend = claimedFromVesting;
        uint256 toBurn = vestingData[msg.sender].esTapLocked;
        //then add half of the remaining
        toSend += ((toBurn - claimedFromVesting) / 2);
        require(toSend <= toBurn, 'value not right');

        forceClaimed = toSend - claimedFromVesting;

        vestingData[msg.sender].totalBurned += toBurn;
        vestingData[msg.sender].totalEarned += toSend;
        _resetVesting(msg.sender);

        IEsTapOFT(esTapToken).burnFrom(address(this), toBurn);
        IERC20(tapToken).safeTransfer(msg.sender, toSend);

        emit Claimed(msg.sender, toSend, toBurn, true);

        burnableTap += (toBurn - toSend);
    }

    //-- Owner methods --
    /// @notice blacklists an address for accessing the contract
    /// @param _for address to update the blacklist status for
    /// @param _blacklistStatus true/false
    function blacklistUpdate(address _for, bool _blacklistStatus) external onlyOwner {
        blacklisted[_for] = _blacklistStatus;
        emit Blacklisted(_for, _blacklistStatus);
    }

    /// @notice updates vesting duration
    /// @param _seconds the new vesting duration in seconds
    function updateVestingDuration(uint256 _seconds) external onlyOwner {
        emit VestingDurationUpdated(vestingDuration, _seconds);
        vestingDuration = _seconds;
    }

    /// @notice emergency withdraws TAP from the contract
    /// @param _onlyUnused if true withdraws only not-vested TAP
    function emergencyTapWithdraw(bool _onlyUnused) external onlyOwner {
        require(paused, 'unauthorized');
        uint256 tapBalance = IERC20(tapToken).balanceOf(address(this));
        if (tapBalance == 0) return;

        uint256 toWithdraw = _onlyUnused ? tapBalance - usedTap : tapBalance;
        if (toWithdraw == 0) return;

        IERC20(tapToken).safeTransfer(msg.sender, toWithdraw);
        emit EmergencyTapWithdrawal(toWithdraw, _onlyUnused, tapBalance);
    }

    /// @notice sets 'burnableTap' to 0
    /// @dev should be called after TAP is burned
    function resetBurnable() external onlyOwner {
        burnableTap = 0;
    }

    /// @notice sets the pause state
    /// _val true/false
    function setPaused(bool _val) external onlyOwner {
        emit PauseChanged(paused, _val);
        paused = _val;
    }

    //-- Private methods --
    function _vest(
        uint256 _esTapAmount,
        address _from,
        address _for
    ) private {
        vestingData[_for].esTapLocked += _esTapAmount;
        if (vestingData[_for].start == 0) {
            vestingData[_for].start = block.timestamp;
            vestingData[_for].end = block.timestamp + vestingDuration;
        }

        usedTap += _esTapAmount;
        IERC20(esTapToken).safeTransferFrom(_from, address(this), _esTapAmount);
    }

    function _claim(address _for) private returns (uint256 claimable) {
        claimable = claimableAmount(_for);
        if (claimable > 0) {
            vestingData[_for].released += claimable;
            vestingData[_for].totalBurned += claimable;
            vestingData[_for].totalEarned += claimable;

            usedTap -= claimable;
            IEsTapOFT(esTapToken).burnFrom(address(this), claimable);
            IERC20(tapToken).safeTransfer(_for, claimable);
        }
        if (vestingData[_for].released == vestingData[_for].esTapLocked) {
            _resetVesting(msg.sender);
        }
    }

    function _resetVesting(address _for) private {
        vestingData[_for].start = 0;
        vestingData[_for].end = 0;
        vestingData[_for].released = 0;
        vestingData[_for].esTapLocked = 0;
    }

    modifier whenNotPaused() {
        require(!paused, 'paused');
        _;
    }
}
