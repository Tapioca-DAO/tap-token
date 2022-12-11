// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

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

struct TapOption {
    uint128 expiry; // timestamp, as once one wise man said, the sun will go dark before this overflows
    uint128 amount; // amount of entitled TAP. Tap has a max supply of 100*10^24, so this should be fine
    bool exercised;
}

contract OTAP is ERC721 {
    address public immutable minter; // address of the minter
    IERC20 public immutable TAP; // address of the TAP token
    uint256 public mintedOTAP; // total number of OTAP minted
    uint256 public mintedTAP; // total number of TAP minted

    mapping(uint256 => TapOption) public options; // tokenId => Option

    constructor(address _minter, address _TAP) ERC721('Option TAP', 'oTAP') {
        minter = _minter;
        TAP = IERC20(_TAP);
    }

    modifier onlyMinter() {
        require(msg.sender == minter, 'OTAP: only minter');
        _;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(address indexed to, uint256 indexed tokenId, TapOption option);
    event Exercise(address indexed to, uint256 indexed tokenId);

    // =========
    //    READ
    // =========

    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenId);
    }

    /// @notice Return the owner of the tokenId and the attributes of the option.
    function attributes(uint256 tokenId) external view returns (address owner, TapOption memory) {
        return (ownerOf(tokenId), options[tokenId]);
    }

    // ==========
    //    WRITE
    // ==========

    /// @notice mints an OTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _amount amount of entitled TAP
    function mint(
        address _to,
        uint128 _expiry,
        uint128 _amount
    ) external onlyMinter {
        uint256 tokenId = mintedOTAP++;
        _safeMint(_to, tokenId);

        TapOption storage option = options[tokenId];
        option.expiry = _expiry;
        option.amount = _amount;

        emit Mint(_to, tokenId, option);
    }

    /// @notice exercises an oTAP call
    /// @param _tokenId tokenId of the oTAP
    function exercise(uint256 _tokenId) external onlyMinter {
        TapOption memory option = options[_tokenId];
        require(option.expiry >= block.timestamp, 'OTAP: option expired');
        require(!option.exercised, 'OTAP: option already exercised');
        address owner = ownerOf(_tokenId);

        mintedTAP += uint256(option.amount);
        options[_tokenId].exercised = true;
        TAP.transfer(owner, uint256(option.amount));

        emit Exercise(owner, _tokenId);
    }
}
