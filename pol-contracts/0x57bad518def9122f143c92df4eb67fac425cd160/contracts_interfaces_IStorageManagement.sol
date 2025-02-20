// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IStorageManagement {
    struct StorageDetails {
        uint256 totalResourcesInStorage;
        uint256 storageCapacity; 
        string[] resourceTypes;
        uint256[] resourceBalances;
    }

    struct StorageAssignment {
        uint256 storageTokenId;
        uint256[] primaryTokens;
    }

    struct StorageAssignmentCollection {
        uint256 storageTokenId;
        address collectionAddress;
        uint256[] primaryTokens;
    }

    event StorageCapacityUpdated(address indexed contractAddress, uint256 indexed tokenId, uint256 newCapacity);
    event StorageContractAdded(address indexed collectionAddress, address indexed contractAddress);
    event StorageContractRemoved(address indexed contractAddress);
    event ResourceDumped(address indexed collectionAddress, uint256 indexed tokenId, address indexed owner, string resource, uint256 amount);
    event ResourceTransferred(address indexed fromCollection, uint256 indexed fromTokenId, address toCollection, uint256 toTokenId, string resource, uint256 amount);

    function storageContracts(address collectionAddress) external view returns (address);
    function storageContractCount() external view returns (uint256);
    function registeredStorageAddresses(address contractAddress) external view returns (bool);

    function addStorageContract(address collectionAddress, address contractAddress) external;
    function removeStorageContract(address collectionAddress) external;
    function getStorageCapacity(address collectionAddress, uint256 tokenId) external view returns (uint256);
    function getTotalResourcesInStorage(address collectionAddress, uint256 tokenId) external view returns (uint256);
    function checkStorageLimit(address collectionAddress, uint256 tokenId, uint256 amount) external view returns (bool);
    function updateStorageCapacity(address collectionAddress, uint256 tokenId, uint256 newCapacity) external;
    function isStorageEntity(address entity) external view returns (bool);
    function getStorageByCollection(address collectionAddress) external view returns (address);
    function getAllStorageContracts() external view returns (address[] memory collectionAddresses, address[] memory storageAddresses);
    function getResourceBalance(address collectionAddress, uint256 tokenId, string memory resource) external view returns (uint256);
    function getAllResourceBalances(address collectionAddress, uint256 tokenId) external view returns (string[] memory resourceTypes, uint256[] memory resourceBalances);
    function dumpResource(address collectionAddress, uint256 tokenId, string memory resource, uint256 amount) external;
    function getStorageDetails(address collectionAddress, uint256 tokenId) external view returns (StorageDetails memory);
    function addResource(address collectionAddress, uint256 tokenId, address user, string memory resource, uint256 amount) external;
    function transferResource(address fromCollection, uint256 fromTokenId, address fromOwner, address toCollection, uint256 toTokenId, address toOwner, string memory resource, uint256 amount) external;
    function checkUserOwnsRequiredStorageNFT(address user, address collectionAddress, uint256 tokenId) external view returns (bool);
    function requiresOtherNFTForStorage(address collectionAddress) external view returns (bool);
    function assignStorageToPrimary(address primaryCollection, uint256 primaryTokenId, uint256 storageTokenId) external;
    function unassignStorageFromPrimary(address primaryCollection, uint256 primaryTokenId) external;
    function getPrimaryTokensForStorage(address primaryCollection, uint256 storageTokenId) external view returns (uint256[] memory);
    function getAllAssignedToStorage(address user, address piratesCollection, address islandCollection) external view returns (StorageAssignment[] memory);
    function getAllAssignedToStorageMultiCollections(address user, address[] calldata piratesCollections, address islandCollection) external view returns (StorageAssignmentCollection[] memory);
    function getCollectionAddressByStorageContract(address contractAddress) external view returns (address);
    function getAssignedStorage(address collectionAddress, uint256 tokenId) external view returns (address, uint256);
}