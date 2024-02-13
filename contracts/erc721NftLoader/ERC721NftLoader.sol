// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Tapioca
import {INFTLoader} from "../interfaces/INFTLoader.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/// @title ERC721 NFT Loader
/// @notice An ERC721 token that can load NFT URIs from an NFT loader contract. This helps update image URIs for NFTs.
contract ERC721NftLoader is ERC721, Ownable {
    INFTLoader public nftLoader; // NFT URI loader contract

    constructor(string memory _name, string memory _symbol, address _owner) ERC721(_name, _symbol) {
        _transferOwnership(_owner);
    }

    /**
     * @notice Returns the token URI for a given token ID. If the NFT loader contract is not set, it returns an empty string.
     * @inheritdoc ERC721
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (address(nftLoader) == address(0)) {
            return "";
        }
        return INFTLoader(nftLoader).tokenURI(tokenId);
    }

    /**
     * @notice Set the NFT loader contract
     */
    function setNftLoader(address _nftLoader) external onlyOwner {
        nftLoader = INFTLoader(_nftLoader);
    }
}
