// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
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
}

contract TapiocaOptionLiquidityProvision is
    ERC721,
    ERC721Permit,
    BaseBoringBatchable,
    Pausable,
    BoringOwnable
{
    uint256 public tokenCounter; // Counter for token IDs
    mapping(uint256 => LockPosition) public lockPositions; // TokenID => LockPosition

    IYieldBox public immutable yieldBox;

    // Singularity market address => SingularityPool (YieldBox Asset ID is 0 if not active)
    mapping(IERC20 => SingularityPool) public activeSingularities;
    mapping(uint256 => IERC20) public sglAssetIDToAddress; // Singularity market YieldBox asset ID => Singularity market address
    uint256[] public singularities; // Array of active singularity asset IDs

    uint256 public totalSingularityPoolWeights; // Total weight of all active singularity pools

    constructor(
        address _yieldBox,
        address _owner
    )
        ERC721("TapiocaOptionLiquidityProvision", "tOLP")
        ERC721Permit("TapiocaOptionLiquidityProvision")
    {
        yieldBox = IYieldBox(_yieldBox);
        owner = _owner;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(
        address indexed to,
        uint128 indexed sglAssetID,
        LockPosition indexed lockPosition
    );
    event Burn(
        address indexed to,
        uint128 indexed sglAssetID,
        LockPosition indexed lockPosition
    );
    event UpdateTotalSingularityPoolWeights(
        uint256 indexed totalSingularityPoolWeights
    );
    event SetSGLPoolWeight(address indexed sgl, uint256 indexed poolWeight);
    event RegisterSingularity(address indexed sgl, uint256 indexed assetID);
    event UnregisterSingularity(address indexed sgl, uint256 indexed assetID);

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
    function getSingularities() external view returns (uint256[] memory) {
        return singularities;
    }

    /// @notice Returns the active singularity pool data
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
                pools[i] = activeSingularities[
                    sglAssetIDToAddress[_singularities[i]]
                ];
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
    ) external returns (uint256 tokenId) {
        require(_lockDuration != 0, "tOLP: lock duration must be > 0");
        require(_ybShares != 0, "tOLP: shares must be > 0");

        uint256 sglAssetID = activeSingularities[_singularity].sglAssetID;
        require(sglAssetID != 0, "tOLP: singularity not active");

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
        require(_exists(_tokenId), "tOLP: Expired position");

        LockPosition memory lockPosition = lockPositions[_tokenId];
        require(
            block.timestamp >=
                lockPosition.lockTime + lockPosition.lockDuration,
            "tOLP: Lock not expired"
        );
        require(
            activeSingularities[_singularity].sglAssetID ==
                lockPosition.sglAssetID,
            "tOLP: Invalid singularity"
        );

        require(
            _isApprovedOrOwner(msg.sender, _tokenId),
            "tOLP: not owner nor approved"
        );

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
        require(
            activeSingularities[singularity].sglAssetID > 0,
            "tOLP: not registered"
        );
        activeSingularities[singularity].poolWeight = weight;

        emit SetSGLPoolWeight(address(singularity), weight);
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
        require(assetID != 0, "tOLP: invalid asset ID");
        require(
            activeSingularities[singularity].sglAssetID == 0,
            "tOLP: already registered"
        );

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
        require(sglAssetID != 0, "tOLP: not registered");

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
                } else if (
                    _singularities[i] == sglAssetID && i < sglLastIndex
                ) {
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

    /// @notice Compute the total pool weight of all active singularity markets
    function _computeSGLPoolWeights() internal view returns (uint256) {
        uint256 total;
        uint256 len = singularities.length;
        for (uint256 i; i < len; i++) {
            total += activeSingularities[sglAssetIDToAddress[singularities[i]]]
                .poolWeight;
        }

        return total;
    }
}
