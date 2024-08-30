// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Tapioca
import {IPearlmit, PearlmitHandler} from "tap-utils/pearlmit/PearlmitHandler.sol";
import {ERC721NftLoader} from "contracts/erc721NftLoader/ERC721NftLoader.sol";
import {ERC721Permit} from "tap-utils/utils/ERC721Permit.sol"; // TODO audit

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

// TODO naming
/// @notice Struct representing the details of a TAP option
struct TapOption {
    uint128 entry; // time when the option position was created
    uint128 expiry; // timestamp, as once one wise man said, the sun will go dark before this overflows
    uint128 discount; // discount in basis points
    uint256 tOLP; // tOLP token ID
}

/// @title OTAP (Option TAP) Token Contract
/// @notice This contract manages Option TAP tokens, representing options on TAP tokens
/// @dev Implements ERC721 standard with additional option features

contract OTAP is ERC721, ERC721Permit, ERC721Enumerable, ERC721NftLoader, PearlmitHandler, BaseBoringBatchable {
    /// @notice Total number of OTAP tokens minted
    uint256 public mintedOTAP;

    /// @notice Address of the broker who has special privileges
    address public broker;

    /// @notice Mapping of token IDs to their corresponding option details
    mapping(uint256 => TapOption) public options;

    /// @notice Initializes the OTAP contract
    /// @param _pearlmit Address of the Pearlmit contract for permit functionality
    /// @param _owner Address of the contract owner

    constructor(IPearlmit _pearlmit, address _owner)
        ERC721NftLoader("Option TAP", "oTAP", _owner)
        ERC721Permit("Option TAP")
        PearlmitHandler(_pearlmit)
    {}

    // ==========
    //   EVENTS
    // ==========

    /// @notice Emitted when a new OTAP token is minted
    /// @param to Address receiving the minted token
    /// @param tokenId ID of the minted token
    /// @param option Details of the option associated with the token
    event Mint(address indexed to, uint256 indexed tokenId, TapOption indexed option);

    /// @notice Emitted when an OTAP token is burned
    /// @param from Address from which the token is burned
    /// @param tokenId ID of the burned token
    /// @param option Details of the option associated with the burned token
    event Burn(address indexed from, uint256 indexed tokenId, TapOption indexed option);

    // ==========
    //   ERRORS
    // ==========

    /// @notice Error thrown when an action is not authorized
    error NotAuthorized();

    /// @notice Error thrown when a function restricted to the broker is called by another address
    error OnlyBroker();

    /// @notice Error thrown when an action that can only be performed once is attempted again
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
        return _isApprovedOrOwner(_spender, _tokenId)
            || isERC721Approved(_ownerOf(_tokenId), _spender, address(this), _tokenId);
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

    /// @notice Mints a new OTAP token
    /// @dev Only the broker can mint tokens
    /// @param _to Address to receive the minted token
    /// @param _expiry Timestamp when the option expires
    /// @param _discount Discount in basis points
    /// @param _tOLP tOLP token ID associated with this option
    /// @return tokenId The ID of the newly minted token
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
        if (msg.sender != broker) revert OnlyBroker();
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId, options[_tokenId]);
    }

    /// @notice tOB claim
    function brokerClaim() external {
        if (broker != address(0)) revert OnlyOnce();
        broker = msg.sender;
    }

    function _baseURI() internal view override(ERC721, ERC721NftLoader) returns (string memory) {
        return baseURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        virtual
        override(ERC721, ERC721Permit)
    {
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
