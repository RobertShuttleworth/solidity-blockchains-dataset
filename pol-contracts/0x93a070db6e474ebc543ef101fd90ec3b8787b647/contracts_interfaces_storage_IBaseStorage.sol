// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";

interface IBaseStorage {
    event StorageCapacityUpdated(uint256 indexed tokenId, uint256 newCapacity);

    function nftCollection721() external view returns (IERC721);
    function nftCollection1155() external view returns (IERC1155);
    function nftCollectionAddress() external view returns (address);
    function isNft721() external view returns (bool);
    function requiredStorage() external view returns (bool);
    function requiredStorageContract() external view returns (address);
    function storageCapacities(uint256 tokenId) external view returns (uint256);
    function primaryToStorage(address primaryCollection, uint256 primaryTokenId) external view returns (uint256);

    function setRequiredStorage(bool _requiredStorage, address _requiredStorageContract) external;
    function getRequiredStorageContract() external view returns (address);
    function requiresOtherNFTForStorage() external view returns (bool);
    function assignStorageToPrimary(address primaryCollection, uint256 primaryTokenId, uint256 storageTokenId) external;
    function unassignStorageFromPrimary(address primaryCollection, uint256 primaryTokenId) external;
    function isRequiredStorageAssigned(address primaryCollection, uint256 primaryTokenId) external view returns (bool);
    function getAssignedStorage(address primaryCollection, uint256 primaryTokenId) external view returns (uint256);
    function getTotalResourcesInStorage(uint256 tokenId) external view returns (uint256);
    function getResourceBalance(uint256 tokenId, string memory resource) external view returns (uint256);
    function addResource(uint256 tokenId, address user, string memory resource, uint256 amount) external;
    function dumpResource(uint256 tokenId, address owner, string memory resource, uint256 amount) external;
    function transferResource(
        uint256 fromTokenId,
        address fromOwner,
        uint256 toTokenId,
        address toOwner,
        address toStorageContract,
        string memory resource,
        uint256 amount
    ) external;
    function getAllResourceBalances(uint256 tokenId) external view returns (string[] memory, uint256[] memory);
    function getStorageCapacity(uint256 tokenId) external view returns (uint256);
    function updateStorageCapacity(uint256 tokenId, uint256 newCapacity) external;
    function isERC1155(address collectionAddress) external view returns (bool);
    function isERC721(address collectionAddress) external view returns (bool);
    function checkUserOwnsRequiredStorageNFT(address user, uint256 requiredStorageTokenId) external view returns (bool);
}