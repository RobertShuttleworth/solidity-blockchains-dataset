// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./contracts_AuthorizationModifiers.sol";
import "./contracts_interfaces_IResourceManagement.sol";
import "./contracts_interfaces_IStorageManagement.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721Receiver.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155Receiver.sol";
import "./contracts_interfaces_IResourceFarming.sol";

abstract contract BaseStorage is AuthorizationModifiers {
    using Strings for string;

    IERC721 public nftCollection721;
    IERC1155 public nftCollection1155;
    address public nftCollectionAddress;
    bool public isNft721;
    bool public requiredStorage;
    address public requiredStorageContract; // nft collecton 

    // Mapping from token ID to storage capacity
    mapping(uint256 => uint256) public storageCapacities;

    // Mapping from primary token ID to storage token ID
    mapping(address => mapping(uint256 => uint256)) public primaryToStorage;

    mapping(uint256 => uint256[]) public storageToPrimaryTokens;

    event StorageCapacityUpdated(uint256 indexed tokenId, uint256 newCapacity);

    constructor(address _centralAuthorizationRegistry, address _nftCollectionAddress, bool _isNft721, bytes32 _interfaceId) AuthorizationModifiers(_centralAuthorizationRegistry, _interfaceId) {        
        nftCollectionAddress = _nftCollectionAddress;
        isNft721 = _isNft721;
        if (isNft721) {
            nftCollection721 = IERC721(_nftCollectionAddress);
        } else {
            nftCollection1155 = IERC1155(_nftCollectionAddress);
        }
        requiredStorage = false;
        requiredStorageContract = address(0);
    }

    function _setRequiredStorage(bool _requiredStorage, address _requiredStorageContract) internal {
        requiredStorage = _requiredStorage;
        requiredStorageContract = _requiredStorageContract;
    }
    function setRequiredStorage(bool _requiredStorage, address _requiredStorageContract) external onlyAuthorized {
        _setRequiredStorage(_requiredStorage, _requiredStorageContract);
    }

    function getRequiredStorageContract() external view returns (address) {
        return requiredStorageContract;
    }

    function requiresOtherNFTForStorage() external view returns (bool) {
        return requiredStorage;
    }

    function assignStorageToPrimary(address primaryCollection, uint256 primaryTokenId, uint256 storageTokenId) external virtual onlyAuthorized {        
        primaryToStorage[primaryCollection][primaryTokenId] = storageTokenId;
    }

    function unassignStorageFromPrimary(address primaryCollection, uint256 primaryTokenId) external virtual onlyAuthorized {
        primaryToStorage[primaryCollection][primaryTokenId] = 0;
    }

    function isRequiredStorageAssigned(address primaryCollection, uint256 primaryTokenId) external view returns (bool) {
        return primaryToStorage[primaryCollection][primaryTokenId] != 0;
    }

    function getAssignedStorage(address primaryCollection, uint256 primaryTokenId) external view returns (uint256) {
        return primaryToStorage[primaryCollection][primaryTokenId];
    }

    function getResourceManagement() internal view returns (IResourceManagement) {
        return IResourceManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IResourceManagement")));
    }

    function getStorageManagement() internal view returns (IStorageManagement) {
        return IStorageManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IStorageManagement")));
    }

    function getTotalResourcesInStorage(uint256 tokenId) external view virtual returns (uint256) {
        IResourceManagement resourceManagement = getResourceManagement();
        uint256 totalResources = resourceManagement.getTotalResourcesInStorage(address(this), tokenId);
        return totalResources;
    }

    function getResourceBalance(uint256 tokenId, string memory resource) external view virtual returns (uint256) {
        IResourceManagement resourceManagement = getResourceManagement();
        uint256 resourceBalance = resourceManagement.getResourceBalance(address(this), tokenId, resource);
        return resourceBalance;
    }

    function addResource(uint256 tokenId, address user, string memory resource, uint256 amount) external virtual onlyAuthorized(){
        IResourceManagement resourceManagement = getResourceManagement();
        resourceManagement.addResource(address(this), tokenId, user, resource, amount);
    }

    function dumpResource(uint256 tokenId, address owner, string memory resource, uint256 amount) external virtual onlyAuthorized {
        if (isNft721) {            
            require(nftCollection721.ownerOf(tokenId) == owner, "Caller does not own the 721 token");
        } else {            
            require(nftCollection1155.balanceOf(owner, tokenId) > 0, "Caller does not own the 1155 token");
        }
        IResourceManagement resourceManagement = getResourceManagement();
        resourceManagement.burnResource(address(this), tokenId, owner, resource, amount);
    }

    function transferResource(
        uint256 fromTokenId,
        address fromOwner,
        uint256 toTokenId,
        address toOwner,
        address toStorageContract,
        string memory resource,
        uint256 amount
    ) external virtual onlyAuthorized {
        IResourceManagement resourceManagement = getResourceManagement();        
        require(fromOwner != address(0) && toOwner != address(0), "Invalid token ownership");

        resourceManagement.transferResource(
            address(this),
            fromTokenId,
            fromOwner,
            toStorageContract,
            toTokenId,
            toOwner,
            resource,
            amount
        );
    }

    function getAllResourceBalances(uint256 tokenId) external view virtual returns (string[] memory, uint256[] memory) {
        IResourceManagement resourceManagement = getResourceManagement();
        (string[] memory resourceNames, uint256[] memory resourceBalances) = resourceManagement.getAllResourceBalances(address(this), tokenId);
        return (resourceNames, resourceBalances);
    }
    
    function getStorageCapacity(uint256 tokenId) public view virtual returns (uint256) {
        return storageCapacities[tokenId];
    }

    function updateStorageCapacity(uint256 tokenId, uint256 newCapacity) external virtual onlyAuthorized {
        storageCapacities[tokenId] = newCapacity;
        emit StorageCapacityUpdated(tokenId, newCapacity);
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

    function checkUserOwnsRequiredStorageNFT(address user, uint256 requiredStorageTokenId) external view returns (bool) {
        if (_isERC1155(requiredStorageContract)) {
            return IERC1155(requiredStorageContract).balanceOf(user, requiredStorageTokenId) > 0;
        } else if (_isERC721(requiredStorageContract)) {
            return IERC721(requiredStorageContract).ownerOf(requiredStorageTokenId) == user;
        } else {
            revert("Conntract is not ERC1155 or ERC721");
        }
    }

    function getPrimaryTokensForStorage(uint256 storageTokenId) external view returns (uint256[] memory) {
        return storageToPrimaryTokens[storageTokenId];
    }

    function isStorageAssignedToPrimary(address primaryCollection, uint256 primaryTokenId) external view returns (bool) {
        return primaryToStorage[primaryCollection][primaryTokenId] != 0;
    }

    function getResourceFarming() internal view returns (IResourceFarming) {        
        return IResourceFarming(centralAuthorizationRegistry.getContractAddress(keccak256("IResourceFarming")));
    }
}