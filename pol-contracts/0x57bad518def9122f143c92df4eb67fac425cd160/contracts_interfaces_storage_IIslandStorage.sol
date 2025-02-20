// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_interfaces_storage_IBaseStorage.sol";

interface IIslandStorage is IBaseStorage {
    enum IslandSize { ExtraSmall, Small, Medium, Large, Huge }

    struct Island {
        IslandSize size;
        uint256 capacity;
    }

    function islands(uint256 tokenId) external view returns (Island memory);
    function defaultCapacities(IslandSize size) external view returns (uint256);
    function plotNumbers(IslandSize size) external view returns (uint256);

    function initializeIslands(uint8 part) external;
    function getIslandSize(uint256 tokenId) external view returns (IslandSize);
    function getStorageCapacity(uint256 tokenId) external view override returns (uint256);
    function getPlotNumber(uint256 tokenId) external view returns (uint256);
}