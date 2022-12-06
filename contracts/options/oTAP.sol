// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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

struct TapOption {
    uint128 discount; // discount amount in bps
    uint128 expiry; // timestamp, as once one wise man said, the sun will go dark before this overflows
    uint128 amount; // amount of entitled TAP. Tap has a max supply of 100*10^24, so this should be fine
    bool exercised; // whether the option has been exercised
}

contract OTAP is ERC721 {
    uint256 public mintedOTAP; // total number of OTAP minted
    uint256 public mintedTAP; // total number of TAP minted
    address public immutable minter; // address of the minter

    mapping(uint256 => TapOption) public options; // tokenId => Option

    constructor(address _minter) ERC721('oTAP', 'oTAP') {
        minter = _minter;
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

    // @notice Return the owner of the tokenId and the attributes of the option.
    function attributes(uint256 tokenId) external view returns (address owner, TapOption memory) {
        return (ownerOf(tokenId), options[tokenId]);
    }

    // ==========
    //    WRITE
    // ==========

    /// @notice mints an OTAP
    /// @param _to address to mint to
    /// @param _discount discount amount in bps
    /// @param _expiry timestamp
    /// @param _amount amount of entitled TAP
    function mint(
        address _to,
        uint128 _discount,
        uint128 _expiry,
        uint128 _amount
    ) external onlyMinter {
        uint256 tokenId = mintedOTAP;
        _safeMint(_to, tokenId);

        TapOption storage option = options[tokenId];
        option.discount = _discount;
        option.expiry = _expiry;
        option.amount = _amount;

        unchecked {
            mintedOTAP++;
        }
        mintedTAP += uint256(_amount);

        emit Mint(_to, tokenId, option);
    }

    function exercise(uint256 _tokenId) external onlyMinter {
        TapOption memory option = options[_tokenId];
        require(option.expiry > block.timestamp, 'OTAP: option expired');
        require(!option.exercised, 'OTAP: option already exercised');

        options[_tokenId].exercised = true;

        emit Exercise(ownerOf(_tokenId), _tokenId);
    }

    function burn(uint256 _tokenId) external {
        require(_isApprovedOrOwner(msg.sender, _tokenId), 'OTAP: not owner nor approved');

        TapOption storage option = options[_tokenId];
        require(option.expiry <= block.timestamp, 'OTAP: option not expired');
        require(!option.exercised, 'OTAP: option already exercised');

        _burn(_tokenId);
    }
}
