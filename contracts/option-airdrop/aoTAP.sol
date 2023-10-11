// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "tapioca-sdk/dist/contracts/util/ERC4494.sol";

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

struct AirdropTapOption {
    uint128 expiry; // timestamp, as once one wise man said, the sun will go dark before this overflows
    uint128 discount; // discount in basis points
    uint256 amount; // amount of eligible TAP
}

contract AOTAP is ERC721, ERC721Permit, BaseBoringBatchable, BoringOwnable {
    uint256 public mintedAOTAP; // total number of AOTAP minted
    address public broker; // address of the onlyBroker

    mapping(uint256 => AirdropTapOption) public options; // tokenId => Option
    mapping(uint256 => string) public tokenURIs; // tokenId => tokenURI

    constructor(
        address _owner
    ) ERC721("Airdrop Option TAP", "aoTAP") ERC721Permit("Airdrop Option TAP") {
        owner = _owner;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(
        address indexed to,
        uint256 indexed tokenId,
        AirdropTapOption indexed option
    );
    event Burn(
        address indexed from,
        uint256 indexed tokenId,
        AirdropTapOption indexed option
    );

    // =========
    //    READ
    // =========

    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return tokenURIs[_tokenId];
    }

    function isApprovedOrOwner(
        address _spender,
        uint256 _tokenId
    ) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @notice Return the owner of the tokenId and the attributes of the option.
    function attributes(
        uint256 _tokenId
    ) external view returns (address, AirdropTapOption memory) {
        return (ownerOf(_tokenId), options[_tokenId]);
    }

    /// @notice Check if a token exists
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    // ==========
    //    WRITE
    // ==========

    function setTokenURI(uint256 _tokenId, string calldata _tokenURI) external {
        require(
            _isApprovedOrOwner(msg.sender, _tokenId),
            "AOTAP: only approved or owner"
        );
        tokenURIs[_tokenId] = _tokenURI;
    }

    /// @notice mints an AOTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _discount TAP discount in basis points
    function mint(
        address _to,
        uint128 _expiry,
        uint128 _discount,
        uint256 _amount
    ) external returns (uint256 tokenId) {
        require(msg.sender == broker, "AOTAP: only onlyBroker");
        tokenId = ++mintedAOTAP;
        _safeMint(_to, tokenId);

        AirdropTapOption storage option = options[tokenId];
        option.expiry = _expiry;
        option.discount = _discount;
        option.amount = _amount;

        emit Mint(_to, tokenId, option);
    }

    /// @notice burns an AOTAP
    /// @param _tokenId tokenId to burn
    function burn(uint256 _tokenId) external {
        require(
            _isApprovedOrOwner(msg.sender, _tokenId),
            "AOTAP: only approved or owner"
        );
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId, options[_tokenId]);
    }

    /// @notice ADB claim
    function brokerClaim() external {
        require(broker == address(0), "AOTAP: only once");
        broker = msg.sender;
    }
}
