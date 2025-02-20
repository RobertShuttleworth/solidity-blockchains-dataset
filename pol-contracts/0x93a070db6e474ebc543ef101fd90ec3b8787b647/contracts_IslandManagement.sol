// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_AuthorizationModifiers.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import "./contracts_interfaces_IStorageManagement.sol";
import "./contracts_interfaces_IResourceManagement.sol";
import "./contracts_interfaces_IResourceFarming.sol";
import "./openzeppelin_contracts_utils_Strings.sol";


contract IslandManagement is AuthorizationModifiers {
    using Strings for string;

    IERC721 public islandNftContract;

    // Mapping to store the capital island for each user
    mapping(address => uint256) private userCapitalIslands;

    // Array to store all users who have set their capital island
    address[] private usersWithCapitalIslands;

    // Mapping to check if a user is already in the usersWithCapitalIslands array
    mapping(address => bool) private isUserInList;

    // Events
    event CapitalIslandSet(address indexed owner, uint256 indexed islandId);
    event ResourceTransferredToIsland(address indexed user, uint256 indexed islandId, string resource, uint256 amount);
    event ResourceTransferredToCapital(address indexed user, uint256 indexed islandId, string resource, uint256 amount);

    constructor(address _centralAuthorizationRegistryContract, address _islandNftContract) AuthorizationModifiers(_centralAuthorizationRegistryContract, keccak256("IIslandManagement")) {
        islandNftContract = IERC721(_islandNftContract);        
    }

    function getStorageManagement() internal view returns (IStorageManagement) {
        return IStorageManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IStorageManagement")));
    }

    function getResourceManagement() internal view returns (IResourceManagement) {
        return IResourceManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IResourceManagement")));
    }

    // Function to get the storage capacity of an island
    function getIslandStorageCapacity(address owner, uint256 islandId) external view returns (uint256) {
        IStorageManagement storageManagement = getStorageManagement();
        return storageManagement.getStorageCapacity(address(islandNftContract), islandId);
    }

    // Function to verify if an island has enough storage capacity
    function verifyIslandStorage(address owner, uint256 islandId, uint256 amount) external view returns (bool) {
        IStorageManagement storageManagement = getStorageManagement();
        return storageManagement.checkStorageLimit(address(islandNftContract), islandId, amount);
    }

    function _setCapitalIsland(address user, uint256 islandId) internal {        
        userCapitalIslands[user] = islandId;

        if (!isUserInList[user]) {
            usersWithCapitalIslands.push(user);
            isUserInList[user] = true;
        }
    }

    // Function to set the capital island for a user
    function setCapitalIsland(uint256 islandId) public {
        require(islandNftContract.ownerOf(islandId) == msg.sender, "User does not own this island");
        _setCapitalIsland(msg.sender, islandId);
        emit CapitalIslandSet(msg.sender, islandId);
    }

    function setManyCapitalIslands(address[] memory users, uint256[] memory islandIds) external onlyAuthorized() {
        require(users.length == islandIds.length, "Users and islandIds arrays must have the same length");
        for (uint256 i = 0; i < users.length; i++) {
            _setCapitalIsland(users[i], islandIds[i]);
        }
    }

    // Function to get the capital island of a user
    function getCapitalIsland(address owner) external view returns (uint256) {
        return userCapitalIslands[owner];
    }

    function getResourceFarming() internal view returns (IResourceFarming) {
        return IResourceFarming(centralAuthorizationRegistry.getContractAddress(keccak256("IResourceFarming")));
    }

    function _isERC1155(address collectionAddress) internal view returns (bool) {
        return IERC165(collectionAddress).supportsInterface(type(IERC1155).interfaceId);
    }

    function isERC1155(address collectionAddress) external view returns (bool) {
        return _isERC1155(collectionAddress);
    }

    function _isERC721(address collectionAddress) internal view returns (bool) {
        return IERC165(collectionAddress).supportsInterface(type(IERC721).interfaceId);
    }

    function isERC721(address collectionAddress) external view returns (bool) {
        return _isERC721(collectionAddress);
    }

    // Function to transfer resources to a specific island
    function _transferResourceToIsland(address user, address pirateCollectionContract, uint256 pirateTokenId, uint256 islandId, string memory resource, uint256 amount) internal {
        require(islandNftContract.ownerOf(islandId) == user, "User does not own this island");
        IStorageManagement storageManagement = getStorageManagement();
        // Verify storage capacity
        require(storageManagement.getResourceBalance(pirateCollectionContract, pirateTokenId, resource) >= amount, "Not enough resources in pirate storage");    
        require(storageManagement.checkStorageLimit(address(islandNftContract), islandId, amount), "Insufficient storage capacity in island");

        storageManagement.transferResource(
            pirateCollectionContract, 
            pirateTokenId, 
            user,
            address(islandNftContract), 
            islandId, 
            user,
            resource, 
            amount
        );
        
        emit ResourceTransferredToIsland(user, islandId, resource, amount);
    }

    

    function transferResourceToIsland(address user, address pirateCollectionContract, uint256 pirateTokenId, uint256 islandId, string memory resource, uint256 amount) external onlyAuthorized() {
        _transferResourceToIsland(user, pirateCollectionContract, pirateTokenId, islandId, resource, amount);
    }

    // Function to transfer resources to the capital island
    function transferResourceToCapital(address pirateCollectionContract, uint256 pirateTokenId, string memory resource, uint256 amount) external {
        address user = msg.sender;
        uint256 capitalIslandId = userCapitalIslands[user];
        require(capitalIslandId != 0, "No capital island set for user");

        IResourceFarming resourceFarming = getResourceFarming();
        // Verify that user is the owner of pirateTokenId
        require(_isERC1155(pirateCollectionContract) && IERC1155(pirateCollectionContract).balanceOf(user, pirateTokenId) > 0 || _isERC721(pirateCollectionContract) && IERC721(pirateCollectionContract).ownerOf(pirateTokenId) == user || resourceFarming.isPirateStakedByOwner(pirateCollectionContract, pirateTokenId, user), "User does not own this pirate token");

        // Transfer resources (this would interact with the Resource Management Contract)
        _transferResourceToIsland(user, pirateCollectionContract, pirateTokenId, capitalIslandId, resource, amount);
        emit ResourceTransferredToCapital(user, capitalIslandId, resource, amount);
    }

    // Function to get the list of all users who have set their capital island
    function getUsersWithCapitalIslands() external view returns (address[] memory) {
        return usersWithCapitalIslands;
    }

    // Function to get all capital islands
    function getAllCapitalIslands() external view returns (uint256[] memory) {
        uint256[] memory capitalIslands = new uint256[](usersWithCapitalIslands.length);
        for (uint256 i = 0; i < usersWithCapitalIslands.length; i++) {
            capitalIslands[i] = userCapitalIslands[usersWithCapitalIslands[i]];
        }
        return capitalIslands;
    }
}