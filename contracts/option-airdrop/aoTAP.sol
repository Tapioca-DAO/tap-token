// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Tapioca
import {IPearlmit, PearlmitHandler} from "tap-utils/pearlmit/PearlmitHandler.sol";
import {ERC721Permit} from "tap-utils/utils/ERC721Permit.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

struct AirdropTapOption {
    uint128 expiry; // timestamp, as once one wise man said, the sun will go dark before this overflows
    uint128 discount; // discount in basis points
    uint256 amount; // amount of eligible TAP
    uint64 phase; // phase of the option
}

contract AOTAP is
    Ownable,
    PearlmitHandler,
    ERC721,
    ERC721Permit,
    ERC721Enumerable,
    BaseBoringBatchable,
    ReentrancyGuard
{
    uint256 public mintedAOTAP; // total number of AOTAP minted
    address public broker; // address of the onlyBroker

    string public baseURI;

    mapping(uint256 => AirdropTapOption) public options; // tokenId => Option
    mapping(uint256 => string) public tokenURIs; // tokenId => tokenURI

    constructor(IPearlmit _pearlmit, address _owner)
        ERC721("Airdrop Option TAP", "aoTAP")
        ERC721Permit("Airdrop Option TAP")
        PearlmitHandler(_pearlmit)
    {
        _transferOwnership(_owner);
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(address indexed to, uint256 indexed tokenId, AirdropTapOption indexed option);
    event Burn(address indexed from, uint256 indexed tokenId, AirdropTapOption indexed option);

    error NotAuthorized();
    error OnlyBroker();
    error OnlyOnce();

    // =========
    //    READ
    // =========

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId)
            || isERC721Approved(_ownerOf(_tokenId), _spender, address(this), _tokenId);
    }

    /// @notice Return the owner of the tokenId and the attributes of the option.
    function attributes(uint256 _tokenId) external view returns (address, AirdropTapOption memory) {
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

    /// @notice mints an AOTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _discount TAP discount in basis points
    function mint(address _to, uint128 _expiry, uint128 _discount, uint256 _amount, uint64 _phase)
        external
        nonReentrant
        returns (uint256 tokenId)
    {
        if (msg.sender != broker) revert OnlyBroker();

        tokenId = ++mintedAOTAP;
        AirdropTapOption storage option = options[tokenId];
        option.expiry = _expiry;
        option.discount = _discount;
        option.amount = _amount;
        option.phase = _phase;

        _safeMint(_to, tokenId);
        emit Mint(_to, tokenId, option);
    }

    /// @notice burns an AOTAP
    /// @param _tokenId tokenId to burn
    function burn(uint256 _tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) revert NotAuthorized();
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId, options[_tokenId]);
    }

    /// @notice ADB claim
    function brokerClaim() external {
        if (broker != address(0)) revert OnlyOnce();
        broker = msg.sender;
    }

    /**
     * @notice Set the base URI for all token IDs.
     */
    function setBaseURI(string calldata __baseURI) external onlyOwner {
        baseURI = __baseURI;
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
