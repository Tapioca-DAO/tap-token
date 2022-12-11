// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import '@boringcrypto/boring-solidity/contracts/BoringOwnable.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '../interfaces/IYieldBox.sol';

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

contract TapiocaOptionLiquidityProvision is ERC721, Pausable, BoringOwnable {
    uint256 public tokenCounter; // Counter for token IDs
    mapping(uint256 => LockPosition) public lockPositions; // TokenID => LockPosition

    IYieldBox public immutable yieldBox;
    mapping(IERC20 => uint256) public activeSingularities; // Singularity market address => YieldBox Asset ID (0 if not active)

    constructor(address _yieldBox) ERC721('TapiocaOptionLiquidityProvision', 'tOLP') {
        yieldBox = IYieldBox(_yieldBox);
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(address indexed to, uint128 indexed sglAssetID, LockPosition lockPosition);
    event Burn(address indexed to, uint128 indexed sglAssetID, LockPosition lockPosition);
    event RegisterSingularity(address sgl, uint256 assetID);
    event UnregisterSingularity(address sgl, uint256 assetID);

    // =========
    //    READ
    // =========

    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenId);
    }

    function getLock(uint256 tokenId) external view returns (LockPosition memory) {
        return lockPositions[tokenId];
    }

    // ==========
    //    WRITE
    // ==========

    /// @notice Locks tOLR tokens for a given duration
    /// @param _from Address to transfer the SGL tokens from
    /// @param _to Address to mint the tOLP NFT to
    /// @param _singularity Singularity market address
    /// @param _lockDuration Duration of the lock
    /// @param _amount Amount of tOLR tokens to lock
    /// @return tokenId The ID of the minted NFT
    function lock(
        address _from,
        address _to,
        address _singularity,
        uint128 _lockDuration,
        uint128 _amount
    ) external returns (uint256 tokenId) {
        require(_lockDuration > 0, 'tOLP: lock duration must be > 0');
        require(_amount > 0, 'tOLP: amount must be > 0');

        uint256 sglAssetID = activeSingularities[IERC20(_singularity)];
        require(sglAssetID > 0, 'tOLP: singularity not active');

        // Transfer the Singularity position to this contract
        yieldBox.depositAsset(sglAssetID, _from, address(this), _amount, 0);

        // Mint the tOLP NFT position
        tokenId = tokenCounter++;
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
    /// @param _to Address to send the tokens to
    function unlock(uint256 _tokenId, address _to) external returns (uint256 amountOut) {
        LockPosition memory lockPosition = lockPositions[_tokenId];
        require(block.timestamp >= lockPosition.lockTime + lockPosition.lockDuration, 'tOLP: Lock not expired');

        require(_isApprovedOrOwner(msg.sender, _tokenId), 'tOLP: not owner nor approved');
        _burn(_tokenId);

        // Refund for freeing up chain space
        delete lockPositions[_tokenId];

        // Transfer the tOLR tokens back to the owner
        (amountOut, ) = yieldBox.withdraw(lockPosition.sglAssetID, address(this), _to, lockPosition.amount, 0);
        emit Burn(_to, lockPosition.sglAssetID, lockPosition);
    }

    // =========
    //   OWNER
    // =========
    function registerSingularity(IERC20 singularity, uint256 assetID) external onlyOwner {
        require(activeSingularities[singularity] == 0, 'TapiocaOptions: already registered');
        activeSingularities[singularity] = assetID;
        emit RegisterSingularity(address(singularity), assetID);
    }

    function unregisterSingularity(IERC20 singularity) external onlyOwner {
        uint256 sglAssetID = activeSingularities[singularity];
        require(sglAssetID > 0, 'TapiocaOptions: not registered');
        activeSingularities[singularity] = 0;
        emit UnregisterSingularity(address(singularity), sglAssetID);
    }
}
