// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "tapioca-sdk/dist/contracts/util/ERC4494.sol";

// ********************************************************************************
// *******************************,                 ,******************************
// *************************                               ************************
// *********************                                       ********************
// *****************,                     @@@                     ,****************
// ***************                        @@@                        **************
// *************                    (@@@@@@@@@@@@@(                    ************
// ***********                   @@@@@@@@#@@@#@@@@@@@@                   **********
// **********                 .@@@@@      @@@      @@@@@.                 *********
// *********                 @@@@@        @@@        @@@@@                 ********
// ********                 @@@@@&        @@@         /@@@@                 *******
// *******                 &@@@@@@        @@@          #@@@&                 ******
// ******,                 @@@@@@@@,      @@@           @@@@                 ,*****
// ******                 #@@@&@@@@@@@@#  @@@           &@@@(                 *****
// ******                 %@@@%   @@@@@@@@@@@@@@@(      (@@@%                 *****
// ******                 %@@@%          %@@@@@@@@@@@@. %@@@#                 *****
// ******.                /@@@@           @@@    *@@@@@@@@@@*                .*****
// *******                 @@@@           @@@       &@@@@@@@                 ******
// *******                 /@@@@          @@@        @@@@@@/                .******
// ********                 %&&&&         @@@        &&&&&#                 *******
// *********                 *&&&&#       @@@       &&&&&,                 ********
// **********.                 %&&&&&,    &&&    ,&&&&&%                 .*********
// ************                   &&&&&&&&&&&&&&&&&&&                   ***********
// **************                     .#&&&&&&&%.                     *************
// ****************                       %%%                       ***************
// *******************                    %%%                    ******************
// **********************                                    .*********************
// ***************************                           **************************
// ************************************..     ..***********************************

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
    event Mint(
        address indexed to,
        uint256 indexed tokenId,
        TapOption indexed option
    );
    event Burn(
        address indexed from,
        uint256 indexed tokenId,
        TapOption indexed option
    );

    error NotAuthorized();
    error OnlyBroker();
    error OnlyOnce();

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
    ) external view returns (address, TapOption memory) {
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
            "OTAP: only approved or owner"
        );
        tokenURIs[_tokenId] = _tokenURI;
    }

    /// @notice mints an OTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _discount TAP discount in basis points
    /// @param _tOLP tOLP token ID
    function mint(
        address _to,
        uint128 _expiry,
        uint128 _discount,
        uint256 _tOLP
    ) external returns (uint256 tokenId) {
        require(msg.sender == broker, "OTAP: only onlyBroker");
        tokenId = ++mintedOTAP;
        _safeMint(_to, tokenId);

        TapOption storage option = options[tokenId];
        option.expiry = _expiry;
        option.discount = _discount;
        option.tOLP = _tOLP;

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
