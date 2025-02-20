// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_interfaces_IStorageManagement.sol";
import "./contracts_interfaces_IFeeManagement.sol";
import "./contracts_interfaces_IUpgradeConstructionTime.sol";
import "./contracts_interfaces_IResourceManagement.sol";
import "./contracts_interfaces_storage_IIslandStorage.sol";
import "./contracts_AuthorizationModifiers.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";

import "./openzeppelin_contracts_token_ERC721_IERC721Receiver.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155Receiver.sol";
import "./hardhat_console.sol";

contract StorageUpgrade is AuthorizationModifiers, IERC1155Receiver, IERC721Receiver, ReentrancyGuard, Pausable {
    
    struct UpgradeLevel {
        uint256 storageToAdd;
        mapping(string => uint256) resourcesRequired;
        string[] resourceTypes;
        IslandSize minIslandSize;
    }

    struct StakingInfo {
        address owner;
        uint256 startTime;
        uint256 endTime;
        uint256 nftId;
        address nftCollection;
        bool claimed;
    }

    struct UpgradeInfoDetails {
        uint256 currentLevel;
        uint256 nextLevel;
        uint256 startTime;
        uint256 endTime;
        bool claimed;
    }

    enum IslandSize { ExtraSmall, Small, Medium, Large, Huge }

    struct UpgradeRequirements {
        address storageCollectionAddress;
        uint256 storageTokenId;        
        uint256 currentLevel;
        uint256 nextLevel;
        uint256 upgradeTime;
        uint256 rumFee;
        uint256 maticFee;
        uint256 foodFish;
        uint256 foodCoconut;
        uint256 foodMeat;
        uint256 foodBarrelPackedFish;
        uint256 foodBarrelPackedMeat;
        string[] resourceTypes;
        uint256[] resourceAmounts;
    }

    mapping(uint256 => UpgradeLevel) public upgradeLevels;
    mapping(address => mapping(uint256 => StakingInfo)) public stakingInfo;
    mapping(address => mapping(uint256 => uint256)) public tokenLevels;
    mapping(uint256 => uint256) public constructionDifficulties;
    mapping(address => mapping(address => uint256[])) public stakedTokens; // user -> collection -> tokens[]

    address public genesisPiratesAddress;
    address public genesisIslandsAddress;
    address public inhabitantsAddress;

    mapping(address => mapping(address => bool)) private stakersByCollection; // collection => staker => isStaking
    mapping(address => address[]) private collectionStakers; // collection => all staker addresses

    mapping(address => mapping(uint256 => bool)) public isStorageBeingUpgraded; // storageCollection => storageTokenId => isBeingUpgraded

    event StorageUpgraded(address indexed user, address indexed collectionAddress, uint256 indexed tokenId, uint256 newLevel, uint256 newCapacity);
    event StorageUpgradeStarted(
        address indexed user,
        address indexed collectionAddress,
        uint256 indexed tokenId,
        address storageCollectionAddress,
        uint256 storageTokenId,
        uint256 currentLevel,
        uint256 nextLevel,
        uint256 startTime,
        uint256 endTime,
        bool useRum,
        string foodChoice
    );

    constructor(address _centralAuthorizationRegistry, address _genesisPiratesAddress, address _genesisIslandsAddress, address _inhabitantsAddress) 
        AuthorizationModifiers(_centralAuthorizationRegistry, keccak256("IStorageUpgrade")) {        
        _initializeUpgradeLevels();
        _initializeConstructionDifficulties();
        genesisPiratesAddress = _genesisPiratesAddress;
        genesisIslandsAddress = _genesisIslandsAddress;
        inhabitantsAddress = _inhabitantsAddress;
    }

    function _initializeUpgradeLevels() internal {
        for (uint256 i = 1; i <= 25; i++) {
            UpgradeLevel storage level = upgradeLevels[i];
            if (i <= 5) {
                level.storageToAdd = 100*1e18;
                level.resourceTypes = new string[](2);
                level.resourceTypes[0] = "wood";
                level.resourceTypes[1] = "cotton";
                level.resourcesRequired["wood"] = 5*1e18;
                level.resourcesRequired["cotton"] = 25*1e18;
                level.minIslandSize = IslandSize.ExtraSmall;
            } else if (i <= 10) {
                level.storageToAdd = 200*1e18;
                level.resourceTypes = new string[](3);
                level.resourceTypes[0] = "wood";
                level.resourceTypes[1] = "planks";
                level.resourceTypes[2] = "cotton";
                level.resourcesRequired["wood"] = 20*1e18;
                level.resourcesRequired["planks"] = 100*1e18;
                level.resourcesRequired["cotton"] = 50*1e18;
                level.minIslandSize = IslandSize.Small;
            } else if (i <= 15) {
                level.storageToAdd = 300*1e18;
                level.resourceTypes = new string[](3);
                level.resourceTypes[0] = "wood";
                level.resourceTypes[1] = "planks";
                level.resourceTypes[2] = "stone";
                level.resourcesRequired["wood"] = 100*1e18;
                level.resourcesRequired["planks"] = 500*1e18;
                level.resourcesRequired["stone"] = 50*1e18;
                level.minIslandSize = IslandSize.Medium;
            } else if (i <= 20) {
                level.storageToAdd = 400*1e18;
                level.resourceTypes = new string[](4);
                level.resourceTypes[0] = "wood";
                level.resourceTypes[1] = "planks";
                level.resourceTypes[2] = "stone";
                level.resourceTypes[3] = "bricks";
                level.resourcesRequired["wood"] = 400*1e18;
                level.resourcesRequired["planks"] = 2000*1e18;
                level.resourcesRequired["stone"] = 200*1e18;
                level.resourcesRequired["bricks"] = 1000*1e18;
                level.minIslandSize = IslandSize.Large;
            } else {
                level.storageToAdd = 500*1e18;
                level.resourceTypes = new string[](5);
                level.resourceTypes[0] = "wood";
                level.resourceTypes[1] = "planks";
                level.resourceTypes[2] = "stone";
                level.resourceTypes[3] = "bricks";
                level.resourceTypes[4] = "gold bars";
                level.resourcesRequired["wood"] = 1000*1e18;
                level.resourcesRequired["planks"] = 4000*1e18;
                level.resourcesRequired["stone"] = 1000*1e18;
                level.resourcesRequired["bricks"] = 5000*1e18;
                level.resourcesRequired["gold bars"] = 100*1e18;
                level.minIslandSize = IslandSize.Huge;
            }
        }
    }

    function _initializeConstructionDifficulties() internal {
        // Set construction difficulties based on tiers
        constructionDifficulties[1] = 1; // Levels 1-5
        constructionDifficulties[2] = 2; // Levels 6-10
        constructionDifficulties[3] = 3; // Levels 11-15
        constructionDifficulties[4] = 4; // Levels 16-20
        constructionDifficulties[5] = 5; // Levels 21-25        
    }

    modifier validPirateCollection(address collectionAddress) {
        require(address(centralAuthorizationRegistry.getPirateNftContract(collectionAddress)) != address(0), "Invalid collection address");
        _;
    }

    function getStorageManagement() internal view returns (IStorageManagement) {        
        return IStorageManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IStorageManagement")));
    }

    function getResourceManagement() internal view returns (IResourceManagement) {
        return IResourceManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IResourceManagement")));
    }

    function getUpgradeConstructionTime() internal view returns (IUpgradeConstructionTime)   {
        return IUpgradeConstructionTime(centralAuthorizationRegistry.getContractAddress(keccak256("IUpgradeConstructionTime")));
    }

    function getFeeManagement() internal view returns (IFeeManagement) {
        return IFeeManagement(centralAuthorizationRegistry.getContractAddress(keccak256("IFeeManagement")));
    }

    function getCurrentLevel(address collectionAddress, uint256 tokenId) internal view returns (uint256) {
        return tokenLevels[collectionAddress][tokenId];
    }

    function setCurrentLevel(address collectionAddress, uint256 tokenId, uint256 level) internal {
        tokenLevels[collectionAddress][tokenId] = level;
    }

    function upgradeStorage(address collectionAddress, uint256 tokenId, uint256 level) internal {        
        UpgradeLevel storage upgrade = upgradeLevels[level];              
        // Update the storage capacity
        uint256 newCapacity = getStorageManagement().getStorageCapacity(collectionAddress, tokenId) + upgrade.storageToAdd;
        getStorageManagement().updateStorageCapacity(collectionAddress, tokenId, newCapacity);

        // Set the new level
        setCurrentLevel(collectionAddress, tokenId, level);

        emit StorageUpgraded(msg.sender, collectionAddress, tokenId, level, newCapacity);
    }

    function startUpgradeStorage(uint256 nftId, address nftCollection, bool payInRum, string memory foodChoice) external payable nonReentrant validPirateCollection(nftCollection) whenNotPaused {
        (address storageCollectionAddress, uint256 storageTokenId, address storageContractOrExternal) = _getStorageDetails(nftCollection, nftId);
        
        if (nftCollection == inhabitantsAddress) {
            require(storageTokenId != 0, "Pirate is not assigned to any island");
        }

        // Add check to ensure storage isn't already being upgraded
        require(!isStorageBeingUpgraded[storageCollectionAddress][storageTokenId], "Storage is already being upgraded");

        uint256 currentLevel = getCurrentLevel(storageCollectionAddress, storageTokenId);
        uint256 nextLevel = currentLevel + 1;
        
        // Check if trying to upgrade beyond max level
        if (nextLevel == 26) {
            revert("Max level reached");
        }
        require(nextLevel > 0 && nextLevel <= 25, "Invalid upgrade level");
        require(stakingInfo[nftCollection][nftId].endTime == 0, "NFT already staked");

        require(_checkIslandSize(
            storageCollectionAddress, 
            storageTokenId, 
            storageContractOrExternal, 
            upgradeLevels[nextLevel].minIslandSize,
            nextLevel
        ), "Island size too small");
        
        require(_checkResources(storageContractOrExternal, storageTokenId, upgradeLevels[nextLevel]), "Insufficient resources");  
        
        uint256 constructionTime = calculateConstructionTime(nftCollection, nftId, nextLevel);

        // Calculate fees
        IFeeManagement feeManagement = getFeeManagement();
        uint256 daysRequired = calculateDaysRequired(constructionTime);  // Round up to nearest day
        uint256 totalRumFee = daysRequired * feeManagement.rumFeePerDay();
        uint256 totalMaticFee = daysRequired * feeManagement.maticFeePerDay();

        if (payInRum) {
            require(IERC20(feeManagement.rumToken()).balanceOf(msg.sender) >= totalRumFee, "Insufficient RUM balance");                        
        } else {
            require(msg.value >= totalMaticFee, "Insufficient MATIC sent");                        
        }

        uint256 endTime = block.timestamp + constructionTime;
        
        stakingInfo[nftCollection][nftId] = StakingInfo(msg.sender, block.timestamp, endTime, nftId, nftCollection, false);
        
        stakedTokens[msg.sender][nftCollection].push(nftId);

        if (isERC1155(nftCollection)) { 
            IERC1155 nftContract = IERC1155(nftCollection);
            require(nftContract.balanceOf(msg.sender, nftId) > 0, "You do not own this NFT");
            nftContract.safeTransferFrom(msg.sender, address(this), nftId, 1, "");
        } else {            
            IERC721 nftContract = IERC721(nftCollection);
            require(nftContract.ownerOf(nftId) == msg.sender, "You do not own this NFT");
            nftContract.safeTransferFrom(msg.sender, address(this), nftId);
        }

        // Payment logic
        if (payInRum) {            
            getFeeManagement().useRum(msg.sender, daysRequired);    
        } else {            
            payable(feeManagement.maticFeeRecipient()).transfer(totalMaticFee);            
        }

        _spendResources(storageContractOrExternal, storageTokenId, msg.sender, upgradeLevels[nextLevel], foodChoice, daysRequired);


        // Emit the start upgrade event
        emit StorageUpgradeStarted(
            msg.sender,
            nftCollection,
            nftId,
            storageCollectionAddress,
            storageTokenId,
            currentLevel,
            nextLevel,
            block.timestamp,
            endTime,
            payInRum,
            foodChoice
        );        

        // Track staker address if not already tracked
        if (!stakersByCollection[nftCollection][msg.sender]) {
            stakersByCollection[nftCollection][msg.sender] = true;
            collectionStakers[nftCollection].push(msg.sender);
        }

        // Mark storage as being upgraded
        isStorageBeingUpgraded[storageCollectionAddress][storageTokenId] = true;
    }

    function finishStorageUpgrade(address nftCollection, uint256 nftId) external nonReentrant whenNotPaused {
        StakingInfo memory info = stakingInfo[nftCollection][nftId]; // Cache in memory
        require(info.owner == msg.sender, "Not the owner");
        require(block.timestamp >= info.endTime, "Upgrade not finished");
        require(!info.claimed, "NFT already claimed");

        if (isERC1155(nftCollection)) {
            IERC1155 nftContract = IERC1155(nftCollection);
            nftContract.safeTransferFrom(address(this), info.owner, nftId, 1, "");
        } else if (isERC721(nftCollection)) {
            IERC721 nftContract = IERC721(nftCollection);
            nftContract.safeTransferFrom(address(this), info.owner, nftId);
        }

        (address storageCollectionAddress, uint256 storageTokenId, ) = _getStorageDetails(nftCollection, nftId);
        uint256 currentLevel = getCurrentLevel(storageCollectionAddress, storageTokenId);
        uint256 nextLevel = currentLevel + 1;
        upgradeStorage(storageCollectionAddress, storageTokenId, nextLevel);
        _removeStakedToken(msg.sender, nftCollection, nftId);
        delete stakingInfo[nftCollection][nftId];

        // Remove staker tracking if they have no more staked tokens
        if (getAllStakedTokens(msg.sender, nftCollection).length == 0) {
            stakersByCollection[nftCollection][msg.sender] = false;            
            removeStakerFromCollection(msg.sender, nftCollection);
        }

        // Mark storage as no longer being upgraded
        isStorageBeingUpgraded[storageCollectionAddress][storageTokenId] = false;
    }

    function removeStakerFromCollection(address staker, address collection) internal {
        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < collectionStakers[collection].length; i++) {
            if (collectionStakers[collection][i] == staker) {
                index = i;
                break;
            }
        }
        
        if (index != type(uint256).max) {
            // Move the last element to the position being deleted (if it's not already the last element)
            if (index != collectionStakers[collection].length - 1) {
                collectionStakers[collection][index] = collectionStakers[collection][collectionStakers[collection].length - 1];
            }
            collectionStakers[collection].pop();
        }
}


    function isERC1155(address nftCollection) internal view returns (bool) {
        // Check if the contract supports the ERC1155 interface
        try IERC1155(nftCollection).supportsInterface(type(IERC1155).interfaceId) returns (bool isSupported) {
            return isSupported;
        } catch {
            return false;
        }
    }

    function isERC721(address nftCollection) internal view returns (bool) {
        try IERC721(nftCollection).supportsInterface(type(IERC721).interfaceId) returns (bool isSupported) {
            return isSupported;
        } catch {
            return false;
        }
    }

    function calculateConstructionTime(address nftCollection, uint256 nftId, uint256 nextLevel) internal view returns (uint256) {
        uint256 difficulty = getConstructionDifficulty(nextLevel);
        uint256 constructionTime = getUpgradeConstructionTime().calculateUpgradeTime(nftCollection, nftId, difficulty);
        if (constructionTime == 0) {
            revert("Pirate has no skills to upgrade storage");
        }
        return constructionTime;
    }

    function getConstructionDifficulty(uint256 level) internal view returns (uint256) {                
        if (level <= 5) return constructionDifficulties[1];
        if (level <= 10) return constructionDifficulties[2];
        if (level <= 15) return constructionDifficulties[3];
        if (level <= 20) return constructionDifficulties[4];
        return constructionDifficulties[5];
    }

    function _isIslandSizeSufficient(uint256 currentSize, IslandSize minSize) internal pure returns (bool) {
        // ExtraSmall is the smallest, then Small, Medium, Large, Huge
        if (minSize == IslandSize.ExtraSmall) {
            // ExtraSmall requirement can be met by any size
            return true;
        }
        
        if (uint256(minSize) == currentSize) {
            return true;
        }

        // For Huge islands
        if (currentSize == uint256(IslandSize.Huge)) {
            return true;
        }

        // For Large islands
        if (currentSize == uint256(IslandSize.Large)) {
            return minSize != IslandSize.Huge;
        }

        // For Medium islands
        if (currentSize == uint256(IslandSize.Medium)) {
            return minSize != IslandSize.Huge && minSize != IslandSize.Large;
        }

        // For Small islands
        if (currentSize == uint256(IslandSize.Small)) {
            return minSize == IslandSize.Small;
        }

        return false;
    }

    function _checkIslandSize(address storageCollectionAddress, uint256 storageTokenId, address storageContractOrExternal, IslandSize requiredSize, uint256 nextLevel) internal view returns (bool) {        
        uint256 currentSizeUint;
        
        if (storageCollectionAddress == genesisIslandsAddress) {
            // For islands, check actual island size
            IIslandStorage islandStorage = IIslandStorage(storageContractOrExternal);
            currentSizeUint = uint256(islandStorage.getIslandSize(storageTokenId));
        } else if (storageCollectionAddress == genesisPiratesAddress) {
            // For Genesis Pirates using their own storage, allow up to level 10
            currentSizeUint = nextLevel <= 10 ? 1 : 0; // Treat as Small size for levels 1-10            
        } else {
            currentSizeUint = 0;
        }
        
        // Get required size based on next level
        uint256 levelRequiredSize;
        if (nextLevel <= 5) {
            levelRequiredSize = 0; // ExtraSmall
        } else if (nextLevel <= 10) {
            levelRequiredSize = 1; // Small
        } else if (nextLevel <= 15) {
            levelRequiredSize = 2; // Medium
        } else if (nextLevel <= 20) {
            levelRequiredSize = 3; // Large
        } else {
            levelRequiredSize = 4; // Huge
        }

        return currentSizeUint >= levelRequiredSize;
    }

    function _checkResources(address storageContractOrExternal, uint256 storageTokenId, UpgradeLevel storage upgrade) internal view returns (bool) {
        IResourceManagement resourceManagement = getResourceManagement();
        
        // Use resourceTypes array instead of mapping length
        for (uint256 i = 0; i < upgrade.resourceTypes.length; i++) {
            string memory resource = upgrade.resourceTypes[i];
            uint256 requiredAmount = upgrade.resourcesRequired[resource];
            uint256 userResourceBalance = resourceManagement.getResourceBalance(storageContractOrExternal, storageTokenId, resource);
           
            if (userResourceBalance < requiredAmount) {
                revert(string(abi.encodePacked(
                    "Insufficient ",
                    resource
                )));
            }
        }
        return true;
    }

    function _getStorageDetails(address collectionAddress, uint256 tokenId) internal view returns (address storageCollectionAddress, uint256 storageTokenId, address storageContractOrExternal) {
        IStorageManagement storageManagement = getStorageManagement();

        if (storageManagement.requiresOtherNFTForStorage(collectionAddress)) {            
            (storageCollectionAddress, storageTokenId) = storageManagement.getAssignedStorage(collectionAddress, tokenId);
            if (storageCollectionAddress == inhabitantsAddress) {
                storageTokenId = 0;
            }
            storageContractOrExternal = storageManagement.getStorageByCollection(storageCollectionAddress);
        } else {
            storageCollectionAddress = collectionAddress;
            storageTokenId = tokenId;
            storageContractOrExternal = storageManagement.getStorageByCollection(storageCollectionAddress);
        }
    }

    function getStorageDetails(address collectionAddress, uint256 tokenId) public view returns (address storageCollectionAddress, uint256 storageTokenId, address storageContractOrExternal) {
       (storageCollectionAddress, storageTokenId, storageContractOrExternal) = _getStorageDetails(collectionAddress, tokenId);
       return (storageCollectionAddress, storageTokenId, storageContractOrExternal);
    }

    function _spendResources(address storageContractOrExternal, uint256 storageTokenId, address user, UpgradeLevel storage upgrade, string memory foodChoice, uint256 daysRequired) internal {
        IResourceManagement resourceManagement = getResourceManagement();
        // Use resourceTypes array instead of mapping
        for (uint256 i = 0; i < upgrade.resourceTypes.length; i++) {
            string memory resource = upgrade.resourceTypes[i];
            uint256 requiredAmount = upgrade.resourcesRequired[resource];
            resourceManagement.burnResource(storageContractOrExternal, storageTokenId, user, resource, requiredAmount);
        }

        // Spend food resources
        uint256 foodRequired;
        if (keccak256(abi.encodePacked(foodChoice)) == keccak256(abi.encodePacked("fish"))) {
            foodRequired = daysRequired * 1 ether;
        } else if (keccak256(abi.encodePacked(foodChoice)) == keccak256(abi.encodePacked("coconut"))) {
            foodRequired = daysRequired * 2 ether;
        } else if (keccak256(abi.encodePacked(foodChoice)) == keccak256(abi.encodePacked("meat"))) {
            foodRequired = daysRequired * (1 ether / 2);
        } else if (keccak256(abi.encodePacked(foodChoice)) == keccak256(abi.encodePacked("barrel-packed fish"))) {
            foodRequired = daysRequired * (1 ether / 100);
        } else if (keccak256(abi.encodePacked(foodChoice)) == keccak256(abi.encodePacked("barrel-packed meat"))) {
            foodRequired = daysRequired * (1 ether / 200);
        } else {
            revert("Invalid food choice");
        }
        resourceManagement.burnResource(storageContractOrExternal, storageTokenId, user, foodChoice, foodRequired);
    }

    function getUpgradeInfo(address collectionAddress, uint256 tokenId) public view returns (UpgradeInfoDetails memory) {
        // Get staking info using original collection and token ID
        StakingInfo memory info = stakingInfo[collectionAddress][tokenId];
        
        // Get storage details for level checking
        (address storageCollectionAddress, uint256 storageTokenId, ) = _getStorageDetails(collectionAddress, tokenId);
        uint256 currentLevel = getCurrentLevel(storageCollectionAddress, storageTokenId);
        uint256 nextLevel = currentLevel + 1;

        UpgradeInfoDetails memory details;
        details.currentLevel = currentLevel;
        details.nextLevel = nextLevel;
        details.startTime = info.startTime;
        details.endTime = info.endTime;
        details.claimed = info.claimed;

        return details;
    }

    function batchGetUpgradeInfo(address collectionAddress, uint256[] memory tokenIds) public view returns (UpgradeInfoDetails[] memory) {
        UpgradeInfoDetails[] memory upgradeInfoDetailsArray = new UpgradeInfoDetails[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Pass original collection and token ID to getUpgradeInfo
            upgradeInfoDetailsArray[i] = getUpgradeInfo(collectionAddress, tokenIds[i]);
        }

        return upgradeInfoDetailsArray;
    }

    function getWorkingUpgrades(address owner, address collectionAddress) public view returns (uint256[] memory) {
        uint256[] memory tokens = stakedTokens[owner][collectionAddress];
        uint256 count = 0;

        // First pass to count active upgrades
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            if (isUpgradeActive(collectionAddress, tokenId)) {
                count++;
            }
        }

        // Allocate memory for active upgrades
        uint256[] memory activeUpgrades = new uint256[](count);
        uint256 index = 0;

        // Second pass to populate active upgrades
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            if (isUpgradeActive(collectionAddress, tokenId)) {
                activeUpgrades[index] = tokenId;
                index++;
            }
        }

        return activeUpgrades;
    }

    function getTokens(address owner, address collectionAddress) public view returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        uint256[] memory totalTokens = stakedTokens[owner][collectionAddress];
        uint256 workingCount = 0;
        uint256 finishedCount = 0;

        // First pass to count working and finished tokens
        for (uint256 i = 0; i < totalTokens.length; i++) {
            uint256 tokenId = totalTokens[i];
            if (isUpgradeActive(collectionAddress, tokenId)) {
                workingCount++;
            } else {
                finishedCount++;
            }
        }

        // Allocate memory for working and finished tokens
        uint256[] memory workingTokensList = new uint256[](workingCount);
        uint256[] memory finishedTokensList = new uint256[](finishedCount);
        uint256 workingIndex = 0;
        uint256 finishedIndex = 0;

        // Second pass to populate working and finished tokens
        for (uint256 i = 0; i < totalTokens.length; i++) {
            uint256 tokenId = totalTokens[i];
            if (isUpgradeActive(collectionAddress, tokenId)) {
                workingTokensList[workingIndex] = tokenId;
                workingIndex++;
            } else {
                finishedTokensList[finishedIndex] = tokenId;
                finishedIndex++;
            }
        }

        return (totalTokens, workingTokensList, finishedTokensList);
    }

    function isUpgradeActive(address collectionAddress, uint256 tokenId) internal view returns (bool) {
        StakingInfo memory info = stakingInfo[collectionAddress][tokenId];
        return info.endTime > 0 && block.timestamp < info.endTime && !info.claimed;
    }

    function _getAssignedStorage(uint256 tokenId, address collection) internal view returns (address, uint256) {
        (address storageCollection, uint256 assignedStorageId) = getStorageManagement().getAssignedStorage(collection, tokenId);
        return (storageCollection, assignedStorageId);
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    function batchFinishAllUpgrades(address[] memory collectionAddresses, uint256[][] memory tokenIds) external onlyAdmin {
        require(collectionAddresses.length == tokenIds.length, "Mismatched input lengths");

        for (uint256 i = 0; i < collectionAddresses.length; i++) {
            for (uint256 j = 0; j < tokenIds[i].length; j++) {
                uint256 tokenId = tokenIds[i][j];
                address collectionAddress = collectionAddresses[i];

                (address storageCollectionAddress, uint256 storageTokenId, ) = _getStorageDetails(collectionAddress, tokenId);

                // Return the NFT to the original owner
                address owner = stakingInfo[collectionAddress][tokenId].owner;
                if (isERC1155(collectionAddress)) {
                    IERC1155(collectionAddress).safeTransferFrom(address(this), owner, tokenId, 1, "");
                } else if (isERC721(collectionAddress)) {
                    IERC721(collectionAddress).safeTransferFrom(address(this), owner, tokenId);
                }

                // Complete the upgrade process
                uint256 currentLevel = getCurrentLevel(storageCollectionAddress, storageTokenId);
                uint256 nextLevel = currentLevel + 1;
                upgradeStorage(storageCollectionAddress, storageTokenId, nextLevel);

                _removeStakedToken(owner, collectionAddress, tokenId);
                delete stakingInfo[collectionAddress][tokenId];
                
                // Remove staker tracking if they have no more staked tokens
                if (getAllStakedTokens(owner, collectionAddress).length == 0) {
                    stakersByCollection[collectionAddress][owner] = false;            
                    removeStakerFromCollection(owner, collectionAddress);
                }

                // Mark storage as no longer being upgraded
                isStorageBeingUpgraded[storageCollectionAddress][storageTokenId] = false;
            }
        }
    }

    function getNewUpgradeReq(uint256 pirateId, address pirateCollection) external view returns (UpgradeRequirements memory req) {
        require(pirateCollection == genesisPiratesAddress || pirateCollection == inhabitantsAddress, "Invalid collection address");
        (address storageCollectionAddress, uint256 storageTokenId, ) = _getStorageDetails(pirateCollection, pirateId);
        req.currentLevel = getCurrentLevel(storageCollectionAddress, storageTokenId);
        uint256 nextLevel = req.currentLevel + 1;
        if (nextLevel > 25) {
            revert("Max level reached");
        }
        req.nextLevel = nextLevel;
        req.upgradeTime = calculateConstructionTime(pirateCollection, pirateId, nextLevel);
        req.storageCollectionAddress = storageCollectionAddress;
        req.storageTokenId = storageTokenId;
        
        // Calculate fees with partial days
        IFeeManagement feeManagement = getFeeManagement();
        uint256 daysRequired = calculateDaysRequired(req.upgradeTime);  // Round up to nearest day
        req.rumFee = daysRequired * feeManagement.rumFeePerDay();
        req.maticFee = daysRequired * feeManagement.maticFeePerDay();

        // Calculate food requirements
        req.foodFish = daysRequired * 1 ether;
        req.foodCoconut = daysRequired * 2 ether;
        req.foodMeat = daysRequired * (1 ether / 2);
        req.foodBarrelPackedFish = daysRequired * (1 ether / 100);
        req.foodBarrelPackedMeat = daysRequired * (1 ether / 200);

        // Instead of using mapping, use arrays
        UpgradeLevel storage upgrade = upgradeLevels[nextLevel];
        req.resourceTypes = upgrade.resourceTypes;
        req.resourceAmounts = new uint256[](upgrade.resourceTypes.length);
        
        for (uint256 i = 0; i < upgrade.resourceTypes.length; i++) {
            req.resourceAmounts[i] = upgrade.resourcesRequired[upgrade.resourceTypes[i]];
        }

        return req;
    }

    // Add these functions to implement IERC1155Receiver
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // Add this function to implement IERC721Receiver
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // Add this function to implement IERC165 (required by both receivers)
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function calculateDaysRequired(uint256 constructionTime) internal view returns (uint256) {
        uint256 ONE_DAY = getUpgradeConstructionTime().getOneDayValue();
        return (constructionTime + ONE_DAY - 1) / ONE_DAY;
    }

    /// @notice Returns all staked tokens for a given collection
    /// @param collectionAddress The address of the collection to query
    /// @return An array of token IDs that are staked for the given collection
    function getAllStakedTokens(address owner, address collectionAddress) public view returns (uint256[] memory) {
        return stakedTokens[owner][collectionAddress];
    }

    /// @notice Get the current level of a storage for a given collection and token ID
    /// @param collectionAddress The address of the collection
    /// @param tokenId The token ID to check
    /// @return The current level of the storage
    function getStorageLevel(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        return tokenLevels[collectionAddress][tokenId];
    }

    /// @notice Get the current level of storage for a token that requires assigned storage
    /// @param collectionAddress The address of the collection that requires assigned storage
    /// @param tokenId The token ID to check
    /// @return The current level of the assigned storage
    function getStorageLevelForAssignedStorage(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        // Get the assigned storage details
        (address storageCollectionAddress, uint256 storageTokenId,) = _getStorageDetails(collectionAddress, tokenId);

        if (collectionAddress == inhabitantsAddress) {
            require(storageTokenId != 0, "Pirate is not assigned to any island");
        }
        
        // Return the level of the assigned storage
        return tokenLevels[storageCollectionAddress][storageTokenId];
    }

    // Add function to remove token from stakedTokens when upgrade is finished
    function _removeStakedToken(address owner, address collection, uint256 tokenId) internal {
        uint256[] storage tokens = stakedTokens[owner][collection];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                // Move the last element to the position being deleted
                tokens[i] = tokens[tokens.length - 1];
                // Remove the last element
                tokens.pop();
                break;
            }
        }
    }

    function getStakerAddresses(address _collectionAddress) public view returns (address[] memory) {
        address[] memory allStakers = collectionStakers[_collectionAddress];
        uint256 activeCount = 0;
        
        // First count active stakers
        for (uint256 i = 0; i < allStakers.length; i++) {
            if (stakersByCollection[_collectionAddress][allStakers[i]]) {
                activeCount++;
            }
        }
        
        // Create array of active stakers
        address[] memory activeStakers = new address[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allStakers.length; i++) {
            if (stakersByCollection[_collectionAddress][allStakers[i]]) {
                activeStakers[index] = allStakers[i];
                index++;
            }
        }
        
        return activeStakers;
    }
}