// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {ERC721Permit} from "contracts/utils/ERC721Permit.sol"; // TODO audit

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__
*/

// TODO naming
struct TapOption {
    uint128 expiry; // timestamp, as once one wise man said, the sun will go dark before this overflows
    uint128 discount; // discount in basis points
    uint256 tOLP; // tOLP token ID
}

contract OTAP is ERC721, ERC721Permit, BaseBoringBatchable {
    uint256 public mintedOTAP; // total number of OTAP minted
    address public broker; // address of the onlyBroker

    mapping(uint256 => TapOption) public options; // tokenId => Option
    mapping(uint256 => string) public tokenURIs; // tokenId => tokenURI

    constructor() ERC721("Option TAP", "oTAP") ERC721Permit("Option TAP") {}

    // ==========
    //   EVENTS
    // ==========
    event Mint(address indexed to, uint256 indexed tokenId, TapOption indexed option);
    event Burn(address indexed from, uint256 indexed tokenId, TapOption indexed option);

    error NotAuthorized();
    error OnlyBroker();
    error OnlyOnce();

    // =========
    //    READ
    // =========

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return tokenURIs[_tokenId];
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @notice Return the owner of the tokenId and the attributes of the option.
    function attributes(uint256 _tokenId) external view returns (address, TapOption memory) {
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
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) revert NotAuthorized();
        tokenURIs[_tokenId] = _tokenURI;
    }

    /// @notice mints an OTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _discount TAP discount in basis points
    /// @param _tOLP tOLP token ID
    function mint(address _to, uint128 _expiry, uint128 _discount, uint256 _tOLP) external returns (uint256 tokenId) {
        if (msg.sender != broker) revert OnlyBroker();

        tokenId = ++mintedOTAP;
        TapOption storage option = options[tokenId];
        option.expiry = _expiry;
        option.discount = _discount;
        option.tOLP = _tOLP;

        _safeMint(_to, tokenId);
        emit Mint(_to, tokenId, option);
    }

    /// @notice burns an OTAP
    /// @param _tokenId tokenId to burn
    function burn(uint256 _tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) revert NotAuthorized();
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId, options[_tokenId]);
    }

    /// @notice tOB claim
    function brokerClaim() external {
        if (broker != address(0)) revert OnlyOnce();
        broker = msg.sender;
    }
}
