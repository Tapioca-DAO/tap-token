// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {RebaseLibrary, Rebase} from "@boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721Permit} from "tap-utils/utils/ERC721Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Tapioca
import {IPearlmit, PearlmitHandler} from "tap-utils/pearlmit/PearlmitHandler.sol";
import {ISingularity} from "tap-utils/interfaces/bar/ISingularity.sol";
import {ICluster} from "tap-utils/interfaces/periph/ICluster.sol";
import {IBigBang} from "tap-utils/interfaces/bar/IBigBang.sol";
import {IPenrose} from "tap-utils/interfaces/bar/IPenrose.sol";
import {IYieldBox} from "contracts/interfaces/IYieldBox.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

struct LockPosition {
    uint128 sglAssetID; // Singularity market YieldBox asset ID
    uint128 ybShares; // amount of YieldBox shares locked.
    uint128 lockTime; // time when the tokens were locked
    uint128 lockDuration; // duration of the lock
}

struct SingularityPool {
    uint256 sglAssetID; // Singularity market YieldBox asset ID
    uint256 totalDeposited; // total amount of YieldBox shares deposited, used for pool share calculation
    uint256 poolWeight; // Pool weight to calculate emission
    bool rescue; // If true, the pool will be used to rescue funds in case of emergency
}

contract TapiocaOptionLiquidityProvision is
    Ownable,
    PearlmitHandler,
    ERC721,
    ERC721Permit,
    ERC721Enumerable,
    BaseBoringBatchable,
    Pausable,
    ReentrancyGuard
{
    uint256 public tokenCounter; // Counter for token IDs
    mapping(uint256 => LockPosition) public lockPositions; // TokenID => LockPosition

    IYieldBox public immutable yieldBox;
    address public tapiocaOptionBroker;

    // Singularity market address => SingularityPool (YieldBox Asset ID is 0 if not active)
    mapping(IERC20 => SingularityPool) public activeSingularities;
    mapping(uint256 => IERC20) public sglAssetIDToAddress; // Singularity market YieldBox asset ID => Singularity market address
    uint256[] public singularities; // Array of active singularity asset IDs

    uint256 public rescueCooldown = 2 days; // Cooldown before a singularity pool can be put in rescue mode
    mapping(uint256 sglId => uint256 rescueTime) public sglRescueRequest; // Time when the pool was put in rescue mode

    uint256 public totalSingularityPoolWeights; // Total weight of all active singularity pools
    uint256 public immutable EPOCH_DURATION; // 7 days = 604800
    uint256 public  MAX_LOCK_DURATION = 365 days; // 1 year

    IPenrose public penrose;
    ICluster public cluster;

    uint256 public emergencySweepCooldown = 2 days;
    uint256 public lastEmergencySweep;

    // User address => amount of USDO locked, used to cap the amount of USDO that can be locked
    mapping(address user => uint256 lockedUsdo) public userLockedUsdo;
    uint256 public maxDebtBuffer = 22000; // 220% of the total debt
    // Debt penalty starts from 10% and goes down to 0.5% linearly
    uint256 public maxDebtPenalty = 1000;
    uint256 public minDebtPenalty = 500;
    uint256 public totalPenalties; // Total amount of penalties paid

    error NotRegistered();
    error InvalidSingularity();
    error DurationTooShort();
    error DurationTooLong();
    error SharesNotValid();
    error SingularityInRescueMode();
    error SingularityNotActive();
    error PositionExpired();
    error LockNotExpired();
    error AlreadyActive();
    error AssetIdNotValid();
    error DuplicateAssetId();
    error AlreadyRegistered();
    error NotAuthorized();
    error NotInRescueMode();
    error NotActive();
    error RescueCooldownNotReached();
    error TransferFailed();
    error TobIsHolder();
    error NotValid();
    error EmergencySweepCooldownNotReached();
    error TooBig();

    constructor(address _yieldBox, uint256 _epochDuration, IPearlmit _pearlmit, address _penrose, address _owner)
        ERC721("TapiocaOptionLiquidityProvision", "tOLP")
        ERC721Permit("TapiocaOptionLiquidityProvision")
        PearlmitHandler(_pearlmit)
    {
        yieldBox = IYieldBox(_yieldBox);
        EPOCH_DURATION = _epochDuration;
        penrose = IPenrose(_penrose);
        _transferOwnership(_owner);
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(
        address indexed to,
        uint256 indexed sglAssetId,
        address sglAddress,
        uint256 tolpTokenId,
        uint128 lockDuration,
        uint128 ybShares
    );
    event Burn(address indexed from, uint256 indexed sglAssetId, address sglAddress, uint256 tolpTokenId);
    event UpdateTotalSingularityPoolWeights(uint256 totalSingularityPoolWeights);
    event SetSGLPoolWeight(uint256 indexed sglAssetId, address sglAddress, uint256 poolWeight);
    event RequestSglPoolRescue(uint256 indexed sglAssetId, uint256 timestamp);
    event ActivateSGLPoolRescue(uint256 indexed sglAssetId, address sglAddress);
    event RegisterSingularity(uint256 indexed sglAssetId, address sglAddress, uint256 poolWeight);
    event UnregisterSingularity(uint256 indexed sglAssetId, address sglAddress);
    event SetEmergencySweepCooldown(uint256 emergencySweepCooldown);
    event ActivateEmergencySweep();
    event HarvestPenalties(address to, uint256 amount);

    // ===============
    //    MODIFIERS
    // ===============
    modifier updateTotalSGLPoolWeights() {
        _;
        totalSingularityPoolWeights = _computeSGLPoolWeights();
        emit UpdateTotalSingularityPoolWeights(totalSingularityPoolWeights);
    }

    // =========
    //    READ
    // =========
    /// @notice Returns the lock position of a given tOLP NFT and if it's active
    /// @param _tokenId tOLP NFT ID
    function getLock(uint256 _tokenId) external view returns (LockPosition memory) {
        return lockPositions[_tokenId];
    }

    /// @notice Returns the active singularity YieldBox ID markets
    /// @return singularities Array of YieldBox asset IDs
    function getSingularities() external view returns (uint256[] memory) {
        return singularities;
    }

    /// @notice Returns the active singularity pool data, excluding the ones in rescue
    /// @return pools Array of SingularityPool
    function getSingularityPools() external view returns (SingularityPool[] memory) {
        uint256[] memory _singularities = singularities;
        uint256 len = _singularities.length;

        SingularityPool[] memory pools = new SingularityPool[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                SingularityPool memory sgl = activeSingularities[sglAssetIDToAddress[_singularities[i]]];
                // If the pool is in rescue, don't return it
                if (sgl.rescue) {
                    continue;
                }
                pools[i] = sgl;
            }
        }
        return pools;
    }

    /// @notice Returns the total amount of locked YieldBox shares for a given singularity market
    /// @return shares Amount of YieldBox shares locked
    /// @return amount Amount of YieldBox shares locked converted in amount
    function getTotalPoolDeposited(uint256 _sglAssetId) external view returns (uint256 shares, uint256 amount) {
        shares = activeSingularities[sglAssetIDToAddress[_sglAssetId]].totalDeposited;
        amount = yieldBox.toAmount(_sglAssetId, shares, false);
    }

    /// @notice Return an approval or ownership status of a given address for a given tOLP NFT
    /// @param _spender Address to check
    /// @param _tokenId tOLP NFT ID
    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @notice Returns super approve check or if the spender is approved for the tOLP NFT on Pearlmit
    function _isApprovedOrOwner(address _spender, uint256 _tokenId) internal view override returns (bool) {
        return super._isApprovedOrOwner(_spender, _tokenId)
            || isERC721Approved(_ownerOf(_tokenId), _spender, address(this), _tokenId);
    }

    /// @notice Check if a user can lock with debt. Takes into account past locks.
    /// @param _user User address
    /// @param _sglAssetId Singularity asset id
    /// @param _userShare Amount of YieldBox shares to lock
    function canLockWithDebt(address _user, uint256 _sglAssetId, uint256 _userShare) external view returns (bool) {
        return _canLockWithDebt(_user, sglAssetIDToAddress[_sglAssetId], _userShare);
    }

    // ==========
    //    WRITE
    // ==========

    /// @notice Locks YieldBox shares for a given duration
    /// @param _to Address to mint the tOLP NFT to
    /// @param _singularity Singularity market address
    /// @param _lockDuration Duration of the lock
    /// @param _ybShares Amount of YieldBox shares to lock
    /// @return tokenId The ID of the minted NFT
    function lock(address _to, IERC20 _singularity, uint128 _lockDuration, uint128 _ybShares)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 tokenId)
    {
        // Reverts if user debt doesn't cover the lock
        if (!_canLockWithDebt(msg.sender, _singularity, _ybShares)) {
            revert NotAuthorized();
        }

        if (_lockDuration < EPOCH_DURATION) revert DurationTooShort();
        if (_lockDuration > MAX_LOCK_DURATION) revert DurationTooLong();

        if (_ybShares == 0) revert SharesNotValid();

        SingularityPool memory sgl = activeSingularities[_singularity];
        if (sgl.rescue) revert SingularityInRescueMode();

        uint256 sglAssetID = sgl.sglAssetID;
        if (sglAssetID == 0) revert SingularityNotActive();

        // Transfer the Singularity position to this contract
        // yieldBox.transfer(msg.sender, address(this), sglAssetID, _ybShares);
        {
            bool isErr =
                pearlmit.transferFromERC1155(msg.sender, address(this), address(yieldBox), sglAssetID, _ybShares);
            if (isErr) {
                revert TransferFailed();
            }
        }
        activeSingularities[_singularity].totalDeposited += _ybShares;

        // Create the lock position
        tokenId = ++tokenCounter;
        LockPosition storage lockPosition = lockPositions[tokenId];
        lockPosition.lockTime = uint128(block.timestamp);
        lockPosition.sglAssetID = uint128(sglAssetID);
        lockPosition.lockDuration = _lockDuration;
        lockPosition.ybShares = _ybShares;

        // Mint the tOLP NFT position
        _safeMint(_to, tokenId);

        emit Mint(_to, sglAssetID, address(_singularity), tokenId, _lockDuration, _ybShares);
    }

    /// @notice Unlocks tOLP tokens
    /// @param _tokenId ID of the position to unlock
    /// @param _singularity Singularity market address
    function unlock(uint256 _tokenId, IERC20 _singularity) external whenNotPaused {
        if (!_exists(_tokenId)) revert PositionExpired();
        address tokenOwner = _ownerOf(_tokenId);
        if (tokenOwner == tapiocaOptionBroker) revert TobIsHolder(); // First unlock from broker

        LockPosition memory lockPosition = lockPositions[_tokenId];
        SingularityPool memory sgl = activeSingularities[_singularity];

        // Check if debt ratio is below threshold, if so bypass lock expiration
        bool isLockedWithDebt = _canLockWithDebt(tokenOwner, _singularity, uint128(lockPosition.ybShares));
        if (isLockedWithDebt) {
            // If the singularity is in rescue, the lock can be unlocked at any time
            if (!sgl.rescue) {
                // If not, the lock must be expired
                if (block.timestamp < lockPosition.lockTime + lockPosition.lockDuration) revert LockNotExpired();
            }
        }

        if (sgl.sglAssetID != lockPosition.sglAssetID) {
            revert InvalidSingularity();
        }

        _burn(_tokenId);
        delete lockPositions[_tokenId];

        // Transfer the YieldBox position back to the owner
        {
            if (isLockedWithDebt) {
                yieldBox.transfer(address(this), tokenOwner, lockPosition.sglAssetID, lockPosition.ybShares);
            } else {
                uint256 penalty = _getDebtPenaltyAmount(lockPosition);
                yieldBox.transfer(address(this), tokenOwner, lockPosition.sglAssetID, lockPosition.ybShares - penalty);
            }
        }
        activeSingularities[_singularity].totalDeposited -= lockPosition.ybShares;

        emit Burn(tokenOwner, lockPosition.sglAssetID, address(_singularity), _tokenId);
    }

    // =========
    //   OWNER
    // =========

    /**
     * @notice Sets the Tapioca Option Broker address
     */
    function setTapiocaOptionBroker(address _tob) external onlyOwner {
        tapiocaOptionBroker = _tob;
    }

    /// @notice Sets the pool weight of a given singularity market
    /// @param singularity Singularity market address
    /// @param weight Weight of the pool
    function setSGLPoolWeight(IERC20 singularity, uint256 weight) external onlyOwner updateTotalSGLPoolWeights {
        if (activeSingularities[singularity].sglAssetID == 0) {
            revert NotRegistered();
        }
        activeSingularities[singularity].poolWeight = weight;

        emit SetSGLPoolWeight(activeSingularities[singularity].sglAssetID, address(singularity), weight);
    }

    function setRescueCooldown(uint256 _rescueCooldown) external onlyOwner {
        rescueCooldown = _rescueCooldown;
    }

    /**
     * @notice Requests a singularity market to be put in rescue mode. Needs to be activated later on in `activateSGLPoolRescue()`
     * @param _sglAssetID YieldBox asset ID of the singularity market
     */
    function requestSglPoolRescue(uint256 _sglAssetID) external onlyOwner {
        if (_sglAssetID == 0) revert NotRegistered();
        if (sglRescueRequest[_sglAssetID] != 0) revert AlreadyActive();

        sglRescueRequest[_sglAssetID] = block.timestamp;

        emit RequestSglPoolRescue(_sglAssetID, block.timestamp);
    }

    /// @notice Sets the rescue status of a given singularity market
    /// @param singularity Singularity market address
    function activateSGLPoolRescue(IERC20 singularity) external onlyOwner updateTotalSGLPoolWeights {
        SingularityPool memory sgl = activeSingularities[singularity];

        if (sgl.sglAssetID == 0) revert NotRegistered();
        if (sgl.rescue) revert AlreadyActive();
        if (sglRescueRequest[sgl.sglAssetID] == 0) revert NotActive();
        if (block.timestamp < sglRescueRequest[sgl.sglAssetID] + rescueCooldown) revert RescueCooldownNotReached();

        activeSingularities[singularity].rescue = true;

        emit ActivateSGLPoolRescue(sgl.sglAssetID, address(singularity));
    }

    /// @notice Registers a new singularity market
    /// @param singularity Singularity market address
    /// @param assetID YieldBox asset ID of the singularity market
    /// @param weight Weight of the pool
    function registerSingularity(IERC20 singularity, uint256 assetID, uint256 weight)
        external
        onlyOwner
        updateTotalSGLPoolWeights
    {
        if (assetID == 0) revert AssetIdNotValid();
        if (sglAssetIDToAddress[assetID] != IERC20(address(0))) {
            revert DuplicateAssetId();
        }
        if (activeSingularities[singularity].sglAssetID != 0) {
            revert AlreadyRegistered();
        }

        activeSingularities[singularity].sglAssetID = assetID;
        activeSingularities[singularity].poolWeight = weight > 0 ? weight : 1;
        sglAssetIDToAddress[assetID] = singularity;
        singularities.push(assetID);

        emit RegisterSingularity(assetID, address(singularity), activeSingularities[singularity].poolWeight);
    }

    /// @notice Un-registers a singularity market
    /// @param singularity Singularity market address
    function unregisterSingularity(IERC20 singularity) external onlyOwner updateTotalSGLPoolWeights {
        uint256 sglAssetID = activeSingularities[singularity].sglAssetID;
        if (sglAssetID == 0) revert NotRegistered();
        if (!activeSingularities[singularity].rescue) revert NotInRescueMode();

        unchecked {
            uint256[] memory _singularities = singularities;
            uint256 sglLength = _singularities.length;
            uint256 sglLastIndex = sglLength - 1;

            for (uint256 i; i < sglLength; i++) {
                if (_singularities[i] == sglAssetID) {
                    // If in the middle, copy last element on deleted element, then pop
                    delete activeSingularities[singularity];
                    delete sglAssetIDToAddress[sglAssetID];
                    delete sglRescueRequest[sglAssetID];

                    if (i != sglLastIndex) {
                        singularities[i] = _singularities[sglLastIndex];
                    }
                    singularities.pop();
                    emit UnregisterSingularity(uint256(sglAssetID), address(singularity));
                    break;
                }
            }
        }

        emit UnregisterSingularity(uint256(sglAssetID), address(singularity));
    }

    /**
     * @notice updates the Cluster address.
     */
    function setCluster(ICluster _cluster) external onlyOwner {
        if (address(_cluster) == address(0)) revert NotValid();
        cluster = _cluster;
    }

    /**
     * @notice updates the Penrose address.
     */
    function setPenrose(IPenrose _penrose) external onlyOwner {
        if (address(_penrose) == address(0)) revert NotValid();
        penrose = _penrose;
    }

    /**
     * @notice Un/Pauses this contract.
     */
    function setPause(bool _pauseState) external {
        if (!cluster.hasRole(msg.sender, keccak256("PAUSABLE")) && msg.sender != owner()) revert NotAuthorized();
        if (_pauseState) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @notice Set the max debt buffer
    function setMaxDebtBuffer(uint256 _maxDebtBuffer) external onlyOwner {
        maxDebtBuffer = _maxDebtBuffer;
    }

    /// @notice Set the max debt penalty
    function setMaxDebtPenalty(uint256 _maxDebtPenalty) external onlyOwner {
        maxDebtPenalty = _maxDebtPenalty;
    }

    /// @notice Set the min debt penalty
    function setMinDebtPenalty(uint256 _minDebtPenalty) external onlyOwner {
        minDebtPenalty = _minDebtPenalty;
    }

    /**
     * @notice Harvest penalties to a given address
     * Only the `HARVEST_TOLP` role or owner can call this function
     *
     * @param _to Address to send the penalties to
     * @param _amount Amount of penalties to harvest
     */
    function harvestPenalties(address _to, uint256 _amount) external {
        if (!cluster.hasRole(msg.sender, keccak256("HARVEST_TOLP")) && msg.sender != owner()) revert NotAuthorized();
        totalPenalties -= _amount;
        yieldBox.transfer(address(this), _to, 0, _amount);

        emit HarvestPenalties(_to, _amount);
    }

    /**
     * @notice Set the emergency sweep cooldown
     */
    function setEmergencySweepCooldown(uint256 _emergencySweepCooldown) external onlyOwner {
        emergencySweepCooldown = _emergencySweepCooldown;
        emit SetEmergencySweepCooldown(_emergencySweepCooldown);
    }

    /**
     * @notice Activate the emergency sweep cooldown
     */
    function activateEmergencySweep() external onlyOwner {
        lastEmergencySweep = block.timestamp;
        emit ActivateEmergencySweep();
    }

    /**
     * @notice Set the max lock duration.
     */
    function setMaxLockDuration(uint256 _maxLockDuration) external onlyOwner {
        MAX_LOCK_DURATION = _maxLockDuration;
    }

    /**
     * @notice Emergency sweep of a token from the contract
     */
    function emergencySweep() external onlyOwner {
        if (block.timestamp < lastEmergencySweep + emergencySweepCooldown) revert EmergencySweepCooldownNotReached();
        if (!cluster.hasRole(msg.sender, keccak256("TOLP_EMERGENCY_SWEEP"))) revert NotAuthorized();

        uint256 len = singularities.length;
        for (uint256 i; i < len; i++) {
            SingularityPool memory sgl = activeSingularities[sglAssetIDToAddress[singularities[i]]];
            // Retrieve only the ones not in rescue
            if (!sgl.rescue) {
                // Try to sweep the funds even if one fails
                try yieldBox.transfer(
                    address(this), owner(), sgl.sglAssetID, yieldBox.balanceOf(address(this), sgl.sglAssetID)
                ) {} catch {}
            }
        }
    }

    // =========
    //  INTERNAL
    // =========

    /**
     * @notice Convert SGL ERC20 YieldBox shares used by tOLP to USDO amounts
     * Yb share locked == SGL ERC20 shares => Convert SGL ERC20 shares to amounts
     * SGL ERC20 amounts == fraction/total asset share => convert fraction to amount (amount is YB shares)
     * Yb shares to amount)
     *
     * @param _singularity Singularity market address
     * @param _share Amount of SGL ERC20 shares
     */
    function _getUsdoAmountFromTolpShare(IERC20 _singularity, uint256 _share)
        internal
        view
        returns (uint256 usdoAmount)
    {
        SingularityPool memory sglPool = activeSingularities[_singularity];
        ISingularity sgl = ISingularity(address(_singularity));

        // YB shares to SGL ERC20 amount
        uint256 sglERC20Amount = yieldBox.toAmount(sglPool.sglAssetID, _share, false);

        // SGL ERC20 amount/Fraction to USDO Yb shares
        (uint128 elastic, uint128 base) = sgl.totalAsset();
        uint256 UsdoYbShares = RebaseLibrary.toBase(Rebase(elastic, base), sglERC20Amount, false);

        // Yb shares to USDO amount
        usdoAmount = yieldBox.toAmount(sgl._assetId(), UsdoYbShares, false);
    }

    /**
     * @notice Check if a user can lock with debt. Takes into account past locks.
     *
     * @param _user User address
     * @param _singularity Singularity market address
     * @param _userShare Amount of YieldBox shares to lock
     */
    function _canLockWithDebt(address _user, IERC20 _singularity, uint256 _userShare) internal view returns (bool) {
        uint256 usdoTotalDebt = _getTotalBigBangDebtInUSDO(_user);
        uint256 amountToLock = _getUsdoAmountFromTolpShare(_singularity, _userShare);

        usdoTotalDebt = usdoTotalDebt + (usdoTotalDebt * maxDebtBuffer) / 1e4; // total debt  +
        if (amountToLock + userLockedUsdo[_user] > usdoTotalDebt) {
            return false;
        }

        return true;
    }

    /**
     * @notice Get the USDO total debt of a user in the BigBang markets
     */
    function _getTotalBigBangDebtInUSDO(address _user) internal view returns (uint256 usdoTotalDebt) {
        address[] memory markets = penrose.bigBangMarkets();

        // Loop over the markets, get user debt and sum it
        uint256 len = markets.length;
        for (uint256 i = 0; i < len; i++) {
            IBigBang bigBang = IBigBang(markets[i]);
            (uint128 elastic, uint128 base) = bigBang._totalBorrow();
            uint256 userBorrowPart = bigBang._userBorrowPart(_user);
            usdoTotalDebt += RebaseLibrary.toBase(Rebase(elastic, base), userBorrowPart, false);
        }
    }

    /// @notice Compute the total pool weight of all active singularity markets, excluding the ones in rescue
    /// @return total Total weight of all active singularity markets
    function _computeSGLPoolWeights() internal view returns (uint256) {
        uint256 total;
        uint256 len = singularities.length;
        for (uint256 i; i < len; i++) {
            SingularityPool memory sgl = activeSingularities[sglAssetIDToAddress[singularities[i]]];
            if (!sgl.rescue) {
                total += sgl.poolWeight;
            }
        }

        return total;
    }

    /**
     * @notice Get the debt penalty amount for a given lock position. Starts at 10% and goes down to 0.5% linearly.
     * @param _lockPosition Lock position
     */
    function _getDebtPenaltyAmount(LockPosition memory _lockPosition) internal view returns (uint256) {
        uint256 timePassed = block.timestamp - _lockPosition.lockTime;
        // If the lock is expired, no penalty
        if (timePassed >= _lockPosition.lockDuration) {
            return 0;
        }
        // @dev make sure timePassed is not greater than lockDuration, else it'll underflow
        uint256 penalty = maxDebtPenalty - ((maxDebtPenalty - minDebtPenalty) * timePassed) / _lockPosition.lockDuration;
        return (penalty * _lockPosition.ybShares) / 1e4;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return bytes4(0);
    }

    function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        virtual
        override(ERC721, ERC721Permit)
    {
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
