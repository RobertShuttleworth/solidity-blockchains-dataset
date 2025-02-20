// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IGameRenderer {
    function tokenURI(uint tokenId) external view returns (string memory);
    function tokenImage(uint tokenId) external view returns (string memory);
    function tokenHTML(uint tokenId) external view returns (string memory);
    function tokenTraits(uint tokenId) external view returns (string memory);
}