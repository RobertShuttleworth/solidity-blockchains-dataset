// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC721 {
    function setTokenURI(uint256 id, string calldata uri) external;

    function mint(address to) external;

    function getTotalSupply() external view returns (uint256);

    function mint(
        address to,
        uint256 tokenId,
        string calldata uri
    ) external;

    function burn(uint256 tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);
}