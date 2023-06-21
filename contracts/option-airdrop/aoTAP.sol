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
    uint256 amount; // amount eligible TAP
}

contract AOTAP is ERC721, ERC721Permit, BaseBoringBatchable, BoringOwnable {
    uint256 public mintedOTAP; // total number of OTAP minted
    uint256 public mintedTAP; // total number of TAP minted
    address public broker; // address of the onlyBroker

    mapping(uint256 => AirdropTapOption) public options; // tokenId => Option
    mapping(uint256 => string) public tokenURIs; // tokenId => tokenURI

    mapping(address => uint256) public phase1Users; // user address => eligible TAP amount

    // [OG Pearls, Sushi Frens, Tapiocans, Oysters, Cassava]
    bytes32[4] public phase2MerkleRoots; // merkle root of phase 2 airdrop

    uint256 public constant PHASE_1_3_DISCOUNT = 50 * 1e4; // 50%
    uint256 public constant PHASE_2_DISCOUNT_MIN = 30 * 1e4;
    uint256 public constant PHASE_2_DISCOUNT_MAX = PHASE_1_3_DISCOUNT;
    uint256 public constant PHASE_3_DISCOUNT = 33 * 1e4;

    constructor(
        address _owner
    ) ERC721("Airdrop Option TAP", "aoTAP") ERC721Permit("Airdrop Option TAP") {
        owner = _owner;
    }

    modifier onlyBroker() {
        require(msg.sender == broker, "AOTAP: only onlyBroker");
        _;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(
        address indexed to,
        uint256 indexed tokenId,
        AirdropTapOption option
    );
    event Burn(
        address indexed from,
        uint256 indexed tokenId,
        AirdropTapOption option
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

    /// @notice mints an OTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _discount TAP discount in basis points
    function mint(
        address _to,
        uint128 _expiry,
        uint128 _discount
    ) external onlyBroker returns (uint256 tokenId) {
        tokenId = ++mintedOTAP;
        _safeMint(_to, tokenId);

        AirdropTapOption storage option = options[tokenId];
        option.expiry = _expiry;
        option.discount = _discount;

        emit Mint(_to, tokenId, option);
    }

    /// @notice burns an OTAP
    /// @param _tokenId tokenId to burn
    function burn(uint256 _tokenId) external {
        require(
            _isApprovedOrOwner(msg.sender, _tokenId),
            "AOTAP: only approved or owner"
        );
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId, options[_tokenId]);
    }

    /// @notice tOB claim
    function brokerClaim() external {
        require(broker == address(0), "AOTAP: only once");
        broker = msg.sender;
    }

    // ==========
    //    OWNER
    // ==========
    function setPhase2MerkleRoots(
        bytes32[4] calldata _merkleRoots
    ) external onlyOwner {
        phase2MerkleRoots = _merkleRoots;
    }
}
