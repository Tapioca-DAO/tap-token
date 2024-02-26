// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Tapioca
import {ERC721NftLoader} from "tap-token/erc721NftLoader/ERC721NftLoader.sol";
import {ERC721Permit} from "tapioca-periph/utils/ERC721Permit.sol"; // TODO audit

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

// TODO naming
struct TapOption {
    uint128 entry; // time when the option position was created
    uint128 expiry; // timestamp, as once one wise man said, the sun will go dark before this overflows
    uint128 discount; // discount in basis points
    uint256 tOLP; // tOLP token ID
}

contract OTAP is ERC721, ERC721Permit, ERC721NftLoader, BaseBoringBatchable {
    uint256 public mintedOTAP; // total number of OTAP minted
    address public broker; // address of the onlyBroker

    mapping(uint256 => TapOption) public options; // tokenId => Option

    constructor(address _owner) ERC721NftLoader("Option TAP", "oTAP", _owner) ERC721Permit("Option TAP") {}

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

    /**
     * @inheritdoc ERC721NftLoader
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721NftLoader) returns (string memory) {
        return ERC721NftLoader.tokenURI(tokenId);
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

    /// @notice mints an OTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _discount TAP discount in basis points
    /// @param _tOLP tOLP token ID
    function mint(address _to, uint128 _expiry, uint128 _discount, uint256 _tOLP) external returns (uint256 tokenId) {
        if (msg.sender != broker) revert OnlyBroker();

        tokenId = ++mintedOTAP;
        TapOption storage option = options[tokenId];
        option.entry = uint128(block.timestamp);
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
