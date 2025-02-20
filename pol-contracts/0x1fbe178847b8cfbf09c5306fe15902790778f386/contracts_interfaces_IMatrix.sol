// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMatrix {
    function setTokenURI(uint256 id, string calldata uri) external;

    function getTotalSupply() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function mint(address to, string calldata uri) external returns (uint256);

    function burn(uint256 tokenId) external;
}