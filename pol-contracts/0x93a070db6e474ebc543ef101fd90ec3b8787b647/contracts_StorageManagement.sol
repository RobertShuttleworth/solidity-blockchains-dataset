// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_CentralAuthorizationRegistry.sol";
import "./contracts_storageContracts_BaseStorage.sol";
import "./contracts_AuthorizationModifiers.sol";
import "./openzeppelin_contracts_interfaces_IERC721.sol";
import "./openzeppelin_contracts_interfaces_IERC1155.sol";
import "./contracts_interfaces_IIslandNft.sol";

contract StorageManagement is AuthorizationModifiers {
    // Central Authorization Registry Contract

    // Mapping from storage name to storage contract address
    mapping(address => BaseStorage) public storageContracts;
    // Array to store collection addresses
    address[] public collectionAddresses;
    // Counter to keep track of the number of storage contracts
    uint256 public storageContractCount;
    // Mapping to track registered storage addresses
    mapping(address => bool) public registeredStorageAddresses;

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

    constructor(
        address _centralAuthorizationRegistry,
        address _genesisPiratesAddress,
        address _genesisIslandsAddress,
        address _inhabitantsAddress,
        address _pirateStorage,
        address _islandStorage,
        address _inhabitantStorage
    ) AuthorizationModifiers(_centralAuthorizationRegistry, keccak256("IStorageManagement")) {        
        _addStorageContract(_genesisPiratesAddress, _pirateStorage);
        _addStorageContract(_genesisIslandsAddress, _islandStorage);
        _addStorageContract(_inhabitantsAddress, _inhabitantStorage);        
    }

    function _addStorageContract(address collectionAddress, address contractAddress) internal {        
        storageContracts[collectionAddress] = BaseStorage(contractAddress);
        registeredStorageAddresses[contractAddress] = true;
        collectionAddresses.push(collectionAddress);
        storageContractCount++;
        emit StorageContractAdded(collectionAddress, contractAddress);
    }

    function addStorageContract(address collectionAddress, address contractAddress) public onlyAdmin {
        _addStorageContract(collectionAddress, contractAddress);
    }

    function removeStorageContract(address collectionAddress) public onlyAdmin {
        address contractAddress = address(storageContracts[collectionAddress]);
        require(contractAddress != address(0), "Storage contract does not exist");
        delete storageContracts[collectionAddress];
        delete registeredStorageAddresses[contractAddress];
        
        // Remove collectionAddress from collectionAddresses array
        for (uint256 i = 0; i < collectionAddresses.length; i++) {
            if (collectionAddresses[i] == collectionAddress) {
                collectionAddresses[i] = collectionAddresses[collectionAddresses.length - 1];
                collectionAddresses.pop();
                break;
            }
        }

        storageContractCount--;
        emit StorageContractRemoved(contractAddress);
    }

    function getResourceFarming() internal view returns (IResourceManagement) {        
        return IResourceManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IResourceManagement")));
    }

    function getStorageCapacity(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        BaseStorage storageContract = storageContracts[collectionAddress];        
        return storageContract.getStorageCapacity(tokenId);
    }

    function getTotalResourcesInStorage(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        BaseStorage storageContract = storageContracts[collectionAddress];
        return storageContract.getTotalResourcesInStorage(tokenId);
    }

    function checkStorageLimit(address collectionAddress, uint256 tokenId, uint256 amount) public view returns (bool) {
        return getTotalResourcesInStorage(collectionAddress, tokenId) + amount <= getStorageCapacity(collectionAddress, tokenId);
    }

    struct StorageDetails {
        uint256 totalResourcesInStorage;
        uint256 storageCapacity;
        string[] resourceTypes;
        uint256[] resourceBalances;
    }

    function getStorageDetails(address collectionAddress, uint256 tokenId) public view returns (StorageDetails memory) {
        BaseStorage storageContract = storageContracts[collectionAddress];
        
        uint256 totalResources = storageContract.getTotalResourcesInStorage(tokenId);
        uint256 capacity = storageContract.getStorageCapacity(tokenId);
        (string[] memory resourceTypes, uint256[] memory resourceBalances) = storageContract.getAllResourceBalances(tokenId);
        
        return StorageDetails({
            totalResourcesInStorage: totalResources,
            storageCapacity: capacity,
            resourceTypes: resourceTypes,
            resourceBalances: resourceBalances
        });
    }

    function updateStorageCapacity(address collectionAddress, uint256 tokenId, uint256 newCapacity) public onlyAuthorized {
        BaseStorage storageContract = storageContracts[collectionAddress];
        storageContract.updateStorageCapacity(tokenId, newCapacity);
        emit StorageCapacityUpdated(address(storageContract), tokenId, newCapacity);
    }

    function isStorageEntity(address entity) public view returns (bool) {
        return registeredStorageAddresses[entity];
    }

    function getResourceBalance(address collectionAddress, uint256 tokenId, string memory resource) public view returns (uint256) {
        BaseStorage storageContract = storageContracts[collectionAddress];
        return storageContract.getResourceBalance(tokenId, resource);
    }

    function getAllResourceBalances(address collectionAddress, uint256 tokenId) public view returns (string[] memory, uint256[] memory) {
        BaseStorage storageContract = storageContracts[collectionAddress];
        return storageContract.getAllResourceBalances(tokenId);
    }

    function getStorageByCollection(address collectionAddress) public view returns (address) {
        return address(storageContracts[collectionAddress]);
    }

    function addResource(address collectionAddress, uint256 tokenId, address user, string memory resource, uint256 amount) external onlyAuthorized {
        BaseStorage storageContract = storageContracts[collectionAddress];
        storageContract.addResource(tokenId, user, resource, amount);
    }

    function transferResource(
        address fromCollection,
        uint256 fromTokenId,
        address fromOwner,
        address toCollection,
        uint256 toTokenId,
        address toOwner,
        string memory resource,
        uint256 amount
    ) public onlyAuthorized {
        BaseStorage fromStorageContract = storageContracts[fromCollection];
        BaseStorage toStorageContract = storageContracts[toCollection];
        fromStorageContract.transferResource(fromTokenId, fromOwner, toTokenId, toOwner, address(toStorageContract), resource, amount);
        emit ResourceTransferred(fromCollection, fromTokenId, toCollection, toTokenId, resource, amount);
    }

    function dumpResource(address collectionAddress, uint256 tokenId, string memory resource, uint256 amount) public {
        BaseStorage storageContract = storageContracts[collectionAddress];
        storageContract.dumpResource(tokenId, msg.sender, resource, amount);

        emit ResourceDumped(collectionAddress, tokenId, msg.sender, resource, amount);
    }

    function getAllStorageContracts() public view returns (address[] memory, address[] memory) {
        address[] memory storageAddresses = new address[](collectionAddresses.length);
        for (uint256 i = 0; i < collectionAddresses.length; i++) {
            storageAddresses[i] = address(storageContracts[collectionAddresses[i]]);
        }
        return (collectionAddresses, storageAddresses);
    }

    function getAssignedStorage(address collectionAddress, uint256 tokenId) external view returns (address, uint256) {
        BaseStorage storageContract = storageContracts[collectionAddress];
        uint256 assignedStorageId = storageContract.getAssignedStorage(collectionAddress, tokenId);
        if (assignedStorageId == 0) {
            return (collectionAddress, tokenId);
        } else {
            return (storageContract.getRequiredStorageContract(), assignedStorageId);
        }
    }

    function checkUserOwnsRequiredStorageNFT(address user, address collectionAddress, uint256 tokenId) external view returns (bool) {
        BaseStorage storageContract = storageContracts[collectionAddress];
        uint256 assignedStorageId = storageContract.getAssignedStorage(collectionAddress, tokenId);
        if (assignedStorageId == 0) {
            return true;
        } else {
            return storageContract.checkUserOwnsRequiredStorageNFT(user, assignedStorageId);
        }
    }

    function requiresOtherNFTForStorage(address collectionAddress) external view returns (bool) {
        BaseStorage storageContract = storageContracts[collectionAddress];
        return storageContract.requiresOtherNFTForStorage();
    }

    function assignStorageToPrimary(address primaryCollection, uint256 primaryTokenId, uint256 storageTokenId) public {
        BaseStorage storageContract = storageContracts[primaryCollection];

        require(storageContract.requiresOtherNFTForStorage(), "Storage does not require other NFT for storage");
        _assignStorageWithChecks(storageContract, primaryCollection, primaryTokenId, storageTokenId);
        
    }

    function unassignStorageFromPrimary(address primaryCollection, uint256 primaryTokenId) public {
        BaseStorage storageContract = storageContracts[primaryCollection];
        uint256 storageTokenId = storageContract.getAssignedStorage(primaryCollection, primaryTokenId);
        if (storageContract.requiresOtherNFTForStorage() && storageTokenId != 0) {
            require(
                storageContract.checkUserOwnsRequiredStorageNFT(msg.sender, storageTokenId) ||
                (storageContract.isNft721() ? storageContract.nftCollection721().ownerOf(primaryTokenId) == msg.sender : storageContract.nftCollection1155().balanceOf(msg.sender, primaryTokenId) > 0),
                "Caller does not own the required storage NFT or primary token"
            );
            storageContract.unassignStorageFromPrimary(primaryCollection, primaryTokenId);
        } else {
            revert("Storage does not require other NFT for storage");
        }
    }

    function _assignStorageWithChecks(
        BaseStorage storageContract,
        address primaryCollection,
        uint256 primaryTokenId,
        uint256 storageTokenId
    ) internal {
        if (storageContract.isNft721()) {
            require(storageContract.nftCollection721().ownerOf(primaryTokenId) == msg.sender, "Caller does not own the 721 token");
        } else {
            require(storageContract.nftCollection1155().balanceOf(msg.sender, primaryTokenId) > 0, "Caller does not own the 1155 token");
        }
        require(storageContract.checkUserOwnsRequiredStorageNFT(msg.sender, storageTokenId), "Caller does not own the required storage NFT");
        uint256 assignedStorageId = storageContract.getAssignedStorage(primaryCollection, primaryTokenId);
        require(assignedStorageId != storageTokenId, "Storage is already assigned to a primary");
        storageContract.assignStorageToPrimary(primaryCollection, primaryTokenId, storageTokenId);
    }

    function getPrimaryTokensForStorage(address primaryCollection, uint256 storageTokenId) public view returns (uint256[] memory) {
        BaseStorage storageContract = storageContracts[primaryCollection];
        return storageContract.getPrimaryTokensForStorage(storageTokenId);
    }

    function getAllAssignedToStorage(address user, address piratesCollection, address islandCollection) public view returns (StorageAssignment[] memory) {
        IIslandNft islandNFT = IIslandNft(islandCollection);
        uint256 islandBalance = islandNFT.balanceOf(user);
        StorageAssignment[] memory assigned = new StorageAssignment[](islandBalance);

        for (uint256 i = 0; i < islandBalance; i++) {
            uint256 islandTokenId = islandNFT.tokenOfOwnerByIndex(user, i);
            assigned[i] = StorageAssignment(islandTokenId, getPrimaryTokensForStorage(piratesCollection, islandTokenId));
        }
        return assigned;
    }

    function getAllAssignedToStorageMultiCollections(
        address user,
        address[] calldata piratesCollections,
        address islandCollection
    ) external view returns (StorageAssignmentCollection[] memory) {
        IIslandNft islandNFT = IIslandNft(islandCollection);
        uint256 islandBalance = islandNFT.balanceOf(user);
        uint256 totalAssignments = islandBalance * piratesCollections.length;
        StorageAssignmentCollection[] memory assigned = new StorageAssignmentCollection[](totalAssignments);

        uint256 index = 0;
        for (uint256 i = 0; i < islandBalance; i++) {
            uint256 islandTokenId = islandNFT.tokenOfOwnerByIndex(user, i);

            for (uint256 j = 0; j < piratesCollections.length; j++) {
                uint256[] memory tokensForCollection = getPrimaryTokensForStorage(piratesCollections[j], islandTokenId);
                assigned[index] = StorageAssignmentCollection(islandTokenId, piratesCollections[j], tokensForCollection);
                index++;
            }
        }
        return assigned;
    }

    function getCollectionAddressByStorageContract(address contractAddress) external view returns (address) {        
        for (uint256 i = 0; i < collectionAddresses.length; i++) {
            // Directly compare the stored contract address with the provided address
            if (address(storageContracts[collectionAddresses[i]]) == contractAddress) {
                return collectionAddresses[i];
            }
        }
        revert("Collection address not found for the given storage contract");
    }
}