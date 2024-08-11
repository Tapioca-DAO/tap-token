// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
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
import {ICluster} from "tap-utils/interfaces/periph/ICluster.sol";
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
    uint256 public constant MAX_LOCK_DURATION = 100 * 365 days; // 100 years

    ICluster public cluster;

    uint256 public emergencySweepCooldown = 2 days;
    uint256 public lastEmergencySweep;

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
    error DurationNotMultiple();
    error BrokerAlreadySet();

    constructor(address _yieldBox, uint256 _epochDuration, IPearlmit _pearlmit, address _owner)
        ERC721("TapiocaOptionLiquidityProvision", "tOLP")
        ERC721Permit("TapiocaOptionLiquidityProvision")
        PearlmitHandler(_pearlmit)
    {
        yieldBox = IYieldBox(_yieldBox);
        EPOCH_DURATION = _epochDuration;
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
        if (_lockDuration < EPOCH_DURATION) revert DurationTooShort();
        if (_lockDuration > MAX_LOCK_DURATION) revert DurationTooLong();
        if (_lockDuration % EPOCH_DURATION != 0) revert DurationNotMultiple();

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

        // If the singularity is in rescue, the lock can be unlocked at any time
        if (!sgl.rescue) {
            // If not, the lock must be expired
            if (block.timestamp < lockPosition.lockTime + lockPosition.lockDuration) revert LockNotExpired();
        }

        // TODO remove? This is an assertion, and should never happen
        if (sgl.sglAssetID != lockPosition.sglAssetID) {
            revert InvalidSingularity();
        }

        _burn(_tokenId);
        delete lockPositions[_tokenId];

        // Transfer the YieldBox position back to the owner
        yieldBox.transfer(address(this), tokenOwner, lockPosition.sglAssetID, lockPosition.ybShares);
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
        if (tapiocaOptionBroker != address(0)) {
            revert BrokerAlreadySet();
        }
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
     * @dev can only be called by the owner.
     * @param _cluster the new address.
     */
    function setCluster(ICluster _cluster) external onlyOwner {
        if (address(_cluster) == address(0)) revert NotValid();
        cluster = _cluster;
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
