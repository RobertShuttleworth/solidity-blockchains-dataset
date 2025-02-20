// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IParticle {
    // State variables
    function nextTokenId() external view returns (uint256);

    function totalValue() external view returns (uint256);

    function valueOfToken(uint256 tokenId) external view returns (uint256);

    // Events
    event Merge(uint256 indexed fromTokenId, uint256 indexed toTokenId);
    event Split(uint256 indexed fromTokenId, uint256 indexed toTokenId, uint256 value);

    // Minting and updating value
    function safeMint(address to, uint256 value, string calldata uri) external returns (uint256 tokenId);

    function updateValue(uint256 tokenId, uint256 newValue) external;

    // Merge and Split functions
    function merge(uint256 fromTokenId, uint256 toTokenId) external;

    function split(uint256 tokenId, uint256 value) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    // ERC721 required functions
    function tokenURI(uint256 tokenId) external view returns (string memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}