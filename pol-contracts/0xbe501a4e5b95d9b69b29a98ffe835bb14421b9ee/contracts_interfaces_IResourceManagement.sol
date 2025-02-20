// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IResourceManagement {
    event ResourceAdded(address indexed contractAddress, uint256 indexed tokenId, address indexed owner, string resource, uint256 amount);
    event ResourceTransferred(
        address indexed fromContract,
        uint256 indexed fromTokenId,
        address indexed fromOwner,
        address toContract,
        uint256 toTokenId,
        address toOwner,
        string resource,
        uint256 amount
    );
    event ResourceBurned(address indexed contractAddress, uint256 indexed tokenId, address indexed owner, string resource, uint256 amount);

    function addResource(
        address contractAddress,
        uint256 tokenId,
        address owner,
        string memory resource,
        uint256 amount
    ) external;

    function transferResource(
        address fromContract,
        uint256 fromTokenId,
        address fromOwner,
        address toContract,
        uint256 toTokenId,
        address toOwner,
        string memory resource,
        uint256 amount
    ) external;

    function burnResource(
        address contractAddress,
        uint256 tokenId,
        address owner,
        string memory resource,
        uint256 amount
    ) external;

    function getResourceBalance(
        address contractAddress,
        uint256 tokenId,
        string memory resource
    ) external view returns (uint256);

    function getAllResourceBalances(
        address contractAddress,
        uint256 tokenId
    ) external view returns (string[] memory, uint256[] memory);

    function getTotalResourcesInStorage(
        address contractAddress,
        uint256 tokenId
    ) external view returns (uint256);
}