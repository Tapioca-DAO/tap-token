// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
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
    uint128 amount; // amount of tOLR tokens locked.
    uint128 lockTime; // time when the tokens were locked
    uint128 lockDuration; // duration of the lock
}

struct SingularityPool {
    uint256 sglAssetID; // Singularity market YieldBox asset ID
    uint256 totalDeposited; // total amount of tOLR tokens deposited, used for pool share calculation
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
    event SetSGLPoolWeight(address sgl, uint256 poolWeight);
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
    ) external view returns (bool, LockPosition memory) {
        LockPosition memory lockPosition = lockPositions[_tokenId];

        return (_isPositionActive(_tokenId), lockPosition);
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
        uint256 len = singularities.length;

        SingularityPool[] memory pools = new SingularityPool[](len);
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                pools[i] = activeSingularities[
                    sglAssetIDToAddress[singularities[i]]
                ];
            }
        }
        return pools;
    }

    /// @notice Returns the total amount of locked tokens for a given singularity market
    function getTotalPoolDeposited(
        uint256 _sglAssetId
    ) external view returns (uint256) {
        return
            activeSingularities[sglAssetIDToAddress[_sglAssetId]]
                .totalDeposited;
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

    /// @notice Locks tOLR tokens for a given duration
    /// @param _to Address to mint the tOLP NFT to
    /// @param _singularity Singularity market address
    /// @param _lockDuration Duration of the lock
    /// @param _amount Amount of tOLR tokens to lock
    /// @return tokenId The ID of the minted NFT
    function lock(
        address _to,
        IERC20 _singularity,
        uint128 _lockDuration,
        uint128 _amount
    ) external returns (uint256 tokenId) {
        require(_lockDuration > 0, "tOLP: lock duration must be > 0");
        require(_amount > 0, "tOLP: amount must be > 0");

        uint256 sglAssetID = activeSingularities[_singularity].sglAssetID;
        require(sglAssetID > 0, "tOLP: singularity not active");

        // Transfer the Singularity position to this contract
        uint256 sharesIn = yieldBox.toShare(sglAssetID, _amount, false);

        yieldBox.transfer(msg.sender, address(this), sglAssetID, sharesIn);
        activeSingularities[_singularity].totalDeposited += _amount;

        // Mint the tOLP NFT position
        tokenId = ++tokenCounter;
        _safeMint(_to, tokenId);

        // Create the lock position
        LockPosition storage lockPosition = lockPositions[tokenId];
        lockPosition.lockTime = uint128(block.timestamp);
        lockPosition.sglAssetID = uint128(sglAssetID);
        lockPosition.lockDuration = _lockDuration;
        lockPosition.amount = _amount;

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
    ) external returns (uint256 sharesOut) {
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

        // Transfer the tOLR tokens back to the owner
        sharesOut = yieldBox.toShare(
            lockPosition.sglAssetID,
            lockPosition.amount,
            false
        );

        yieldBox.transfer(
            address(this),
            _to,
            lockPosition.sglAssetID,
            sharesOut
        );
        activeSingularities[_singularity].totalDeposited -= lockPosition.amount;

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
        require(assetID > 0, "tOLP: invalid asset ID");
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
        require(sglAssetID > 0, "tOLP: not registered");

        unchecked {
            uint256[] memory _singularities = singularities;
            uint256 sglLength = _singularities.length;
            uint256 sglLastIndex = sglLength - 1;

            for (uint256 i = 0; i < sglLength; i++) {
                // If in the middle, delete data and move last element to the deleted position, then pop
                if (_singularities[i] == sglAssetID && i < sglLastIndex) {
                    delete activeSingularities[singularity];
                    delete sglAssetIDToAddress[sglAssetID];
                    delete singularities[i];

                    singularities[i] = _singularities[sglLastIndex];
                    singularities.pop();

                    break;
                } else {
                    // If last element, just pop
                    delete activeSingularities[singularity];
                    delete sglAssetIDToAddress[sglAssetID];
                    delete singularities[sglLastIndex];
                    singularities.pop();
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
        for (uint256 i = 0; i < len; i++) {
            total += activeSingularities[sglAssetIDToAddress[singularities[i]]]
                .poolWeight;
        }

        return total;
    }

    /// @notice Checks if the lock position is still active
    function _isPositionActive(uint256 tokenId) internal view returns (bool) {
        LockPosition memory lockPosition = lockPositions[tokenId];

        return
            (lockPosition.lockTime + lockPosition.lockDuration) >=
            block.timestamp;
    }

    /// @notice ERC1155 compliance
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }
}
