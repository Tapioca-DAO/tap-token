// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "tapioca-sdk/dist/contracts/util/ERC4494.sol";
import "tapioca-sdk/dist/contracts/YieldBox/contracts/interfaces/IYieldBox.sol";

//
//                 .(%%%%%%%%%%%%*       *
//             #%%%%%%%%%%%%%%%%%%%%*  ####*
//          #%%%%%%%%%%%%%%%%%%%%%#  /####
//       ,%%%%%%%%%%%%%%%%%%%%%%%   ####.  %
//                                #####
//                              #####
//   #####%#####              *####*  ####%#####*
//  (#########(              #####     ##########.
//  ##########             #####.      .##########
//                       ,####/
//                      #####
//  %%%%%%%%%%        (####.           *%%%%%%%%%#
//  .%%%%%%%%%%     *####(            .%%%%%%%%%%
//   *%%%%%%%%%%   #####             #%%%%%%%%%%
//               (####.
//      ,((((  ,####(          /(((((((((((((
//        *,  #####  ,(((((((((((((((((((((
//          (####   ((((((((((((((((((((/
//         ####*  (((((((((((((((((((
//                     ,**//*,.

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
    ERC721,
    ERC721Permit,
    BaseBoringBatchable,
    Pausable,
    BoringOwnable,
    ReentrancyGuard
{
    uint256 public tokenCounter; // Counter for token IDs
    mapping(uint256 => LockPosition) public lockPositions; // TokenID => LockPosition

    IYieldBox public immutable yieldBox;

    // Singularity market address => SingularityPool (YieldBox Asset ID is 0 if not active)
    mapping(IERC20 => SingularityPool) public activeSingularities;
    mapping(uint256 => IERC20) public sglAssetIDToAddress; // Singularity market YieldBox asset ID => Singularity market address
    uint256[] public singularities; // Array of active singularity asset IDs

    uint256 public totalSingularityPoolWeights; // Total weight of all active singularity pools
    uint256 public immutable EPOCH_DURATION; // 7 days = 604800

    error NotRegistered();
    error InvalidSingularity();
    error DurationTooShort();
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

    constructor(
        address _yieldBox,
        uint256 _epochDuration,
        address _owner
    )
        ERC721("TapiocaOptionLiquidityProvision", "tOLP")
        ERC721Permit("TapiocaOptionLiquidityProvision")
    {
        yieldBox = IYieldBox(_yieldBox);
        EPOCH_DURATION = _epochDuration;
        owner = _owner;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(
        address indexed to,
        uint128 indexed sglAssetID,
        LockPosition lockPosition
    );
    event Burn(
        address indexed to,
        uint128 indexed sglAssetID,
        LockPosition lockPosition
    );
    event UpdateTotalSingularityPoolWeights(
        uint256 totalSingularityPoolWeights
    );
    event SetSGLPoolWeight(address indexed sgl, uint256 poolWeight);
    event ActivateSGLPoolRescue(address sgl);
    event RegisterSingularity(address sgl, uint256 assetID);
    event UnregisterSingularity(address sgl, uint256 assetID);

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
    function getLock(
        uint256 _tokenId
    ) external view returns (LockPosition memory) {
        return lockPositions[_tokenId];
    }

    /// @notice Returns the active singularity YieldBox ID markets
    /// @return singularities Array of YieldBox asset IDs
    function getSingularities() external view returns (uint256[] memory) {
        return singularities;
    }

    /// @notice Returns the active singularity pool data, excluding the ones in rescue
    /// @return pools Array of SingularityPool
    function getSingularityPools()
        external
        view
        returns (SingularityPool[] memory)
    {
        uint256[] memory _singularities = singularities;
        uint256 len = _singularities.length;

        SingularityPool[] memory pools = new SingularityPool[](len);
        unchecked {
            for (uint256 i; i < len; ++i) {
                SingularityPool memory sgl = activeSingularities[
                    sglAssetIDToAddress[_singularities[i]]
                ];
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
    function getTotalPoolDeposited(
        uint256 _sglAssetId
    ) external view returns (uint256 shares, uint256 amount) {
        shares = activeSingularities[sglAssetIDToAddress[_sglAssetId]]
            .totalDeposited;
        amount = yieldBox.toAmount(_sglAssetId, shares, false);
    }

    /// @notice Return an approval or ownership status of a given address for a given tOLP NFT
    /// @param _spender Address to check
    /// @param _tokenId tOLP NFT ID
    function isApprovedOrOwner(
        address _spender,
        uint256 _tokenId
    ) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
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
    function lock(
        address _to,
        IERC20 _singularity,
        uint128 _lockDuration,
        uint128 _ybShares
    ) external nonReentrant returns (uint256 tokenId) {
        if (_lockDuration < EPOCH_DURATION) revert DurationTooShort();
        if (_ybShares == 0) revert SharesNotValid();

        SingularityPool memory sgl = activeSingularities[_singularity];
        if (sgl.rescue) revert SingularityInRescueMode();

        uint256 sglAssetID = sgl.sglAssetID;
        if (sglAssetID == 0) revert SingularityNotActive();

        // Transfer the Singularity position to this contract
        yieldBox.transfer(msg.sender, address(this), sglAssetID, _ybShares);
        activeSingularities[_singularity].totalDeposited += _ybShares;

        // Mint the tOLP NFT position
        tokenId = ++tokenCounter;
        _safeMint(_to, tokenId);

        // Create the lock position
        LockPosition storage lockPosition = lockPositions[tokenId];
        lockPosition.lockTime = uint128(block.timestamp);
        lockPosition.sglAssetID = uint128(sglAssetID);
        lockPosition.lockDuration = _lockDuration;
        lockPosition.ybShares = _ybShares;

        emit Mint(_to, uint128(sglAssetID), lockPosition);
    }

    /// @notice Unlocks tOLP tokens
    /// @param _tokenId ID of the position to unlock
    /// @param _singularity Singularity market address
    /// @param _to Address to send the tokens to
    function unlock(
        uint256 _tokenId,
        IERC20 _singularity,
        address _to
    ) external {
        if (!_exists(_tokenId)) revert PositionExpired();

        LockPosition memory lockPosition = lockPositions[_tokenId];
        SingularityPool memory sgl = activeSingularities[_singularity];

        // If the singularity is in rescue, the lock can be unlocked at any time
        if (!sgl.rescue) {
            // If not, the lock must be expired
            if (
                block.timestamp <
                lockPosition.lockTime + lockPosition.lockDuration
            ) revert LockNotExpired();
        }
        if (sgl.sglAssetID != lockPosition.sglAssetID)
            revert InvalidSingularity();

        if (!_isApprovedOrOwner(msg.sender, _tokenId)) revert NotAuthorized();

        _burn(_tokenId);
        delete lockPositions[_tokenId];

        // Transfer the YieldBox position back to the owner
        yieldBox.transfer(
            address(this),
            _to,
            lockPosition.sglAssetID,
            lockPosition.ybShares
        );
        activeSingularities[_singularity].totalDeposited -= lockPosition
            .ybShares;

        emit Burn(_to, lockPosition.sglAssetID, lockPosition);
    }

    // =========
    //   OWNER
    // =========

    /// @notice Sets the pool weight of a given singularity market
    /// @param singularity Singularity market address
    /// @param weight Weight of the pool
    function setSGLPoolWEight(
        IERC20 singularity,
        uint256 weight
    ) external onlyOwner updateTotalSGLPoolWeights {
        if (activeSingularities[singularity].sglAssetID == 0)
            revert NotRegistered();
        activeSingularities[singularity].poolWeight = weight;

        emit SetSGLPoolWeight(address(singularity), weight);
    }

    /// @notice Sets the rescue status of a given singularity market
    /// @param singularity Singularity market address
    function activateSGLPoolRescue(
        IERC20 singularity
    ) external onlyOwner updateTotalSGLPoolWeights {
        SingularityPool memory sgl = activeSingularities[singularity];
        if (sgl.sglAssetID == 0) revert NotRegistered();
        if (sgl.rescue) revert AlreadyActive();

        activeSingularities[singularity].rescue = true;

        emit ActivateSGLPoolRescue(address(singularity));
    }

    /// @notice Registers a new singularity market
    /// @param singularity Singularity market address
    /// @param assetID YieldBox asset ID of the singularity market
    /// @param weight Weight of the pool
    function registerSingularity(
        IERC20 singularity,
        uint256 assetID,
        uint256 weight
    ) external onlyOwner updateTotalSGLPoolWeights {
        if (assetID == 0) revert AssetIdNotValid();
        if (sglAssetIDToAddress[assetID] != IERC20(address(0)))
            revert DuplicateAssetId();
        if (activeSingularities[singularity].sglAssetID != 0)
            revert AlreadyRegistered();

        activeSingularities[singularity].sglAssetID = assetID;
        activeSingularities[singularity].poolWeight = weight > 0 ? weight : 1;
        sglAssetIDToAddress[assetID] = singularity;
        singularities.push(assetID);

        emit RegisterSingularity(address(singularity), assetID);
    }

    /// @notice Un-registers a singularity market
    /// @param singularity Singularity market address
    function unregisterSingularity(
        IERC20 singularity
    ) external onlyOwner updateTotalSGLPoolWeights {
        uint256 sglAssetID = activeSingularities[singularity].sglAssetID;
        if (sglAssetID == 0) revert NotRegistered();
        if (!activeSingularities[singularity].rescue) revert NotInRescueMode();

        unchecked {
            uint256[] memory _singularities = singularities;
            uint256 sglLength = _singularities.length;
            uint256 sglLastIndex = sglLength - 1;

            for (uint256 i; i < sglLength; i++) {
                // If last element, just pop
                if (i == sglLastIndex) {
                    delete activeSingularities[singularity];
                    delete sglAssetIDToAddress[sglAssetID];
                    singularities.pop();
                } else if (_singularities[i] == sglAssetID) {
                    // If in the middle, copy last element on deleted element, then pop
                    delete activeSingularities[singularity];
                    delete sglAssetIDToAddress[sglAssetID];

                    singularities[i] = _singularities[sglLastIndex];
                    singularities.pop();
                    break;
                }
            }
        }

        emit UnregisterSingularity(address(singularity), sglAssetID);
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
            SingularityPool memory sgl = activeSingularities[
                sglAssetIDToAddress[singularities[i]]
            ];
            if (!sgl.rescue) {
                total += sgl.poolWeight;
            }
        }

        return total;
    }
}
