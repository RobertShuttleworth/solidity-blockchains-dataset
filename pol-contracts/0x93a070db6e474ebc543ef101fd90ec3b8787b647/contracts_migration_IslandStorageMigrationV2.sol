// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_storageContracts_BaseStorage.sol";
import "./contracts_StorageManagement.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./contracts_interfaces_storage_IIslandStorage.sol";
import "./contracts_interfaces_IIslandNft.sol";
import "./contracts_IslandManagement.sol";
import "./contracts_interfaces_IResourceManagement.sol";
import "./contracts_AuthorizationModifiers.sol";


contract IslandStorageMigrationV2 is AuthorizationModifiers {
    using Strings for string;

    BaseStorage public oldIslandStorage;
    BaseStorage public newIslandStorage;
    address public CollectionAddress;    
    bool public migrationCompleted = false; // Flag to track if migration has been completed
    address[] public migratedOwners;

    event MigrationCompleted(address indexed owner, uint256 indexed tokenId);

    constructor(
        address _centralAuthorizationRegistry,
        address _oldIslandStorage,
        address _newIslandStorage,        
        address _collectionAddress        
    ) AuthorizationModifiers(_centralAuthorizationRegistry, keccak256("IIslandStorageMigrationV2")) {
        oldIslandStorage = BaseStorage(_oldIslandStorage);
        newIslandStorage = BaseStorage(_newIslandStorage);        
        CollectionAddress = _collectionAddress;
    }

    function getMigratedOwners() public view returns (address[] memory) {
        return migratedOwners;
    }

    function getResourceManagement() internal view returns (IResourceManagement) {
        return IResourceManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IResourceManagement")));
    }

    function migrateTokenResources(uint256 tokenId, address owner) internal {
        IResourceManagement resourceManagement = getResourceManagement();
        (string[] memory resourceTypes, uint256[] memory resourceBalances) = oldIslandStorage.getAllResourceBalances(tokenId);

        for (uint256 i = 0; i < resourceTypes.length; i++) {
            if (resourceBalances[i] > 0) {
                newIslandStorage.addResource(tokenId, owner, resourceTypes[i], resourceBalances[i]);
                // use sender as owner to dump resources                
                resourceManagement.burnResource(address(oldIslandStorage), tokenId, msg.sender, resourceTypes[i], resourceBalances[i]);
                bool ownerExists = false;
                for (uint256 j = 0; j < migratedOwners.length; j++) {
                    if (migratedOwners[j] == owner) {
                        ownerExists = true;
                        break;
                    }
                }
                
                if (!ownerExists) {
                    migratedOwners.push(owner);
                }
            }
        }

        emit MigrationCompleted(owner, tokenId);
    }

     function getTokenIdsByOwner(address owner) public view returns (uint256[] memory) {
        uint256 balance = IIslandNft(CollectionAddress).balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = IIslandNft(CollectionAddress).tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    function migrateOwnerTokens(address owner) public onlyAdmin {
        require(!migrationCompleted, "Migration has already been completed");
        uint256[] memory tokenIds = getTokenIdsByOwner(owner);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            migrateTokenResources(tokenIds[i], owner);
        }
    }

    function updateStorageManagement() public onlyAdmin {
        require(!migrationCompleted, "Migration has already been completed");
        migrationCompleted = true;
    }

    function migrateAllOwners(address[] memory owners) public onlyAdmin {
        require(!migrationCompleted, "Migration has already been completed");
        for (uint256 i = 0; i < owners.length; i++) {
            migrateOwnerTokens(owners[i]);
        }
    }


}