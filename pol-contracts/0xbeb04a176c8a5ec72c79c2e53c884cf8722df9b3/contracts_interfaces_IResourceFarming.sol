// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IResourceFarming {
    struct FarmingInfo {
        address owner;
        address collectionAddress;
        uint256 tokenId;
        uint256 startTime;
        uint256 endTime;
        string resource;
        bool useRum;
        uint256 days_count;
        string resourceToBurn;
    }

    struct RestakeParams {
        string resource;
        uint256 days_count;
        bool useRum;
        string resourceToBurn;
        bool isSet; // To check if the struct is set
    }

    event ResourceFarmed(
        address indexed user,
        address indexed collectionAddress,
        uint256 indexed tokenId,
        string resource,
        uint256 startTime,
        uint256 endTime,
        bool useRum,
        uint256 daysCount,
        string resourceToBurn
    );

    function farmResource(
        address collectionAddress,
        uint256 tokenId,
        string memory resource,
        uint256 days_count,
        bool useRum,
        string memory resourceToBurn,
        bool isRestake
    ) external payable;

    function claimResourcePirate(
        address collectionAddress,
        uint256 tokenId,
        RestakeParams memory restakeParams
    ) external payable;

    function claimAllResources(address collectionAddress) external;

    function getCurrentProduction(address collectionAddress, uint256 tokenId) external view returns (uint256);

    function getTotalToClaim(address collectionAddress, uint256 tokenId) external view returns (uint256);

    function getFarmingInfo(address collectionAddress, uint256 tokenId) external view returns (FarmingInfo memory);

    function getWorkingPirates(address owner, address collectionAddress) external view returns (uint256[] memory);

    function getPirates(address owner, address collectionAddress) external view returns (uint256[] memory, uint256[] memory, uint256[] memory);

    function simulateResourceProduction(
        address collectionAddress,
        uint256 tokenId,
        string memory resource,
        uint256 days_count
    ) external view returns (uint256);

    function farmingInfo(address collectionAddress, uint256 tokenId) external view returns (FarmingInfo memory);

    function workingPirates(address owner, address collectionAddress) external view returns (uint256[] memory);

    function userStakeCounts(address user) external view returns (uint256);

    function isPirateStakedByOwner(address collectionAddress, uint256 tokenId, address owner) external view returns (bool);
}   