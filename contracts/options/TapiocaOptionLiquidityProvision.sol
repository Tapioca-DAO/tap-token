// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

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
    uint128 tOLR_SGL_ID; // tOLR Singularity market ID
    uint128 amount; // amount of tOLR tokens locked.
    uint128 lockTime; // time when the tokens were locked
    uint128 lockDuration; // duration of the lock
}

contract TapiocaOptionLiquidityProvision is ERC721, IERC1155Receiver {
    uint256 public tokenCounter; // Counter for token IDs
    mapping(uint256 => LockPosition) public lockPositions; // TokenID => LockPosition

    IERC1155 public immutable tOLR; // Tapioca Option Lock Registry address

    constructor(address _tOLR) ERC721('TapiocaOptionLiquidityProvision', 'tOLP') {
        tOLR = IERC1155(_tOLR);
    }

    modifier onlyOwner() {
        require(msg.sender == address(tOLR), 'tOLP: only tOLR');
        _;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(address indexed to, uint128 indexed tOLM_SGL_ID, LockPosition lockPosition);
    event Burn(address indexed to, uint128 indexed tOLM_SGL_ID, LockPosition lockPosition);

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

    /// @notice Locks tOLM tokens for a given duration
    /// @param _from Address to mint the token from
    /// @param _to Address to mint the token to
    /// @param _tOLM_SGL_ID Singularity market ID
    /// @param _lockDuration Duration of the lock
    /// @param _amount Amount of tOLM tokens to lock
    /// @return tokenId The ID of the minted NFT
    function mint(
        address _from,
        address _to,
        uint128 _tOLM_SGL_ID,
        uint128 _lockDuration,
        uint128 _amount
    ) external onlyOwner returns (uint256 tokenId) {
        require(_lockDuration > 0, 'tOLP: lock duration must be > 0');
        require(_amount > 0, 'tOLP: amount must be > 0');
        // Transfer the tOLR tokens to this contract
        tOLR.safeTransferFrom(_from, _to, _tOLM_SGL_ID, _amount, '');

        // Mint the tOLP NFT
        tokenId = tokenCounter++;
        _safeMint(_to, tokenId);

        // Create the lock position
        LockPosition storage lockPosition = lockPositions[tokenId];
        lockPosition.tOLR_SGL_ID = _tOLM_SGL_ID;
        lockPosition.lockTime = uint128(block.timestamp);
        lockPosition.lockDuration = _lockDuration;
        lockPosition.amount = _amount;

        emit Mint(_to, _tOLM_SGL_ID, lockPosition);
    }

    /// @notice Unlocks tOLM tokens
    /// @param _tokenId ID of the NFT to unlock
    /// @param _to Address to send the tokens to
    function burn(uint256 _tokenId, address _to) external {
        LockPosition memory lockPosition = lockPositions[_tokenId];
        require(block.timestamp >= lockPosition.lockTime + lockPosition.lockDuration, 'tOLP: Lock not expired');

        require(_isApprovedOrOwner(msg.sender, _tokenId), 'tOLP: not owner nor approved');
        _burn(_tokenId);

        // Transfer the tOLM tokens back to the owner
        tOLR.safeTransferFrom(address(this), _to, lockPosition.tOLR_SGL_ID, lockPosition.amount, '');
        emit Burn(_to, lockPosition.tOLR_SGL_ID, lockPosition);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0x0;
    }
}
