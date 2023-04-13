// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

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

struct TapEntry {
    uint256 expiry; // expiry timestamp
    uint256 tapAmount; // amount of TAP to be released
    uint256 multiplier; // voting power
}

contract TWTap is ERC721, ERC721Permit, BaseBoringBatchable {
    uint256 public mintedTWTap; // total number of twTAP minted
    address public portal; // address of the portal

    mapping(uint256 => TapEntry) public entry; // tokenId => entry

    constructor()
        ERC721("Time Weighted TAP", "twTAP")
        ERC721Permit("Time Weighted TAP")
    {}

    modifier onlyPortal() {
        require(msg.sender == portal, "twTAP: only portal");
        _;
    }

    // ==========
    //   EVENTS
    // ==========
    event Mint(address indexed to, uint256 indexed tokenId, TapEntry option);
    event Burn(address indexed from, uint256 indexed tokenId, TapEntry option);

    // =========
    //    READ
    // =========

    // TODO implement tokenURI
    // function tokenURI(
    //     uint256 _tokenId
    // ) public view override returns (string memory) {
    //     return tokenURIs[_tokenId];
    // }

    function isApprovedOrOwner(
        address _spender,
        uint256 _tokenId
    ) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @notice Return the owner of the tokenId and the attributes of the option.
    function attributes(
        uint256 _tokenId
    ) external view returns (address, TapEntry memory) {
        return (ownerOf(_tokenId), entry[_tokenId]);
    }

    /// @notice Check if a token exists
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    // ==========
    //    WRITE
    // ==========

    // function setTokenURI(uint256 _tokenId, string calldata _tokenURI) external {
    //     require(
    //         _isApprovedOrOwner(msg.sender, _tokenId),
    //         "twTap: only approved or owner"
    //     );
    //     tokenURIs[_tokenId] = _tokenURI;
    // }

    /// @notice mint twTAP
    /// @param _to address to mint to
    /// @param _expiry timestamp
    /// @param _tapAmount amount of TAP to be released
    /// @param _multiplier voting power
    function mint(
        address _to,
        uint256 _expiry,
        uint256 _tapAmount,
        uint256 _multiplier
    ) external onlyPortal returns (uint256 tokenId) {
        tokenId = ++mintedTWTap;
        _safeMint(_to, tokenId);

        TapEntry storage option = entry[tokenId];
        option.expiry = _expiry;
        option.tapAmount = _tapAmount;
        option.multiplier = _multiplier;

        emit Mint(_to, tokenId, option);
    }

    /// @notice burns twTAP
    /// @param _tokenId tokenId to burn
    function burn(uint256 _tokenId) external {
        require(
            _isApprovedOrOwner(msg.sender, _tokenId),
            "twTap: only approved or owner"
        );
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId, entry[_tokenId]);
    }

    /// @notice tDP claim
    function portalClaim() external {
        require(portal == address(0), "twTap: only once");
        portal = msg.sender;
    }
}
