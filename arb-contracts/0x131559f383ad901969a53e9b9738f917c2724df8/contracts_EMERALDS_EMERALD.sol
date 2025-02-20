// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

/**
 * @title SimpleLimitedNFT
 */
contract SimpleLimitedNFT is ERC721, Ownable {
    // Data associated with each NFT
    struct NFTData {
        uint256 internalId; 
        string quality; 
    }

    uint256 public constant MAX_SUPPLY = 100;
    uint256 private _currentTokenId;
    mapping(uint256 => NFTData) private _tokenInfo;

    // Updatable base URI
    string private _baseTokenURI;

    constructor() ERC721("Genesis Stellar Gate Emeralds", "EMERALD") Ownable(msg.sender) {
        _currentTokenId = 0;
        // Set a default base URI (can be anything; we will overwrite it later)
        _baseTokenURI = "https://soc.stellargate.io/img/emeralds/EmeraldPower.png";
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function mintAndSendNFT(
        address to,
        uint256 _internalId,
        string memory _quality
    ) external onlyOwner {
        require(_currentTokenId < MAX_SUPPLY, "Max supply reached");
        
        _currentTokenId++;
        uint256 newTokenId = _currentTokenId;
        _safeMint(to, newTokenId);

        _tokenInfo[newTokenId] = NFTData({
            internalId: _internalId,
            quality: _quality
        });
    }

    function getNFTData(uint256 tokenId) 
        external 
        view 
        returns (uint256 internalId, string memory quality) 
    {
        require(_ownerOf(tokenId) != address(0), "Query for nonexistent token");
        NFTData storage data = _tokenInfo[tokenId];
        return (data.internalId, data.quality);
    }

    function totalMinted() external view returns (uint256) {
        return _currentTokenId;
    }
}