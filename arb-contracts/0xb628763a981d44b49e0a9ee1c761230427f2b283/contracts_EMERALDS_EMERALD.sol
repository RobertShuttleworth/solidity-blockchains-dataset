// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract EMERALD is ERC721, ERC721URIStorage, Ownable {
    // Data associated with each NFT
    struct NFTData {
        uint256 internalId;
        string quality;
    }

    uint256 public constant MAX_SUPPLY = 100;
    uint256 private _currentTokenId;
    mapping(uint256 => NFTData) private _tokenInfo;

    // Event emitted when a token's URI is changed
    event TokenURIChanged(uint256 indexed tokenId, string newUri);

    constructor() ERC721("Genesis Stellar Gate Emeralds", "EMERALD") Ownable(msg.sender) {
        _currentTokenId = 0;
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
        
        // Set initial token URI for new token
        _setTokenURI(newTokenId, "https://soc.stellargate.io/data/uri/emerald/emerald.json");
        
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

    // Returns the total supply of NFTs
    function totalSupply() public view returns (uint256) {
        return _currentTokenId;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "URI set of nonexistent token");
        _setTokenURI(tokenId, _tokenURI);
        emit TokenURIChanged(tokenId, _tokenURI);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721)
        returns (address)
    {
        require(to != address(0), "Transfers and burns are disabled");
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}