// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {CustomERC721} from "./contracts_CustomERC721.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

//import "hardhat/console.sol";

contract Item_V3 is CustomERC721 {
    uint256 private _nextTokenId;
    string private baseItemUri;

    // Default quota increase when registering a new item (can be adjusted by the owner)
    uint16 public defaultQuotaMegabytes;
    uint8 public defaultQuotaNbSouvenirs;

    // Mapping to store UUIDs that have already been minted
    mapping(string uuid => bool minted) private _mintedUUIDs;

    // Structures
    struct Quota {
        uint32 totalMegabytes;
        uint32 usedMegabytes;
        uint16 totalNbSouvenirs;
        uint16 usedNbSouvenirs;
    }

    struct Souvenir {
        uint256 tokenId;
        uint16 size; // in megabytes
        string metadata;
    }

    struct Item {
        uint256[] souvenirTokenIds;
        string ownerHashmail;
        string metadata;
        string[] guardians;
    }

    enum ItemState {
        NOT_REGISTERED,    // Item not exists
        REGISTERED,        // Item registered with an owner
        WITH_GUARDIANS,    // Item has at least one guardian
        WITH_SOUVENIRS    // Item has at least one souvenir
    }

    // Mappings
    // hashmail => Quota; To manage the quotas of an account
    mapping(string hashmail => Quota userQuota) private hashmailToQuotas;

    // hashmail => itemIds registered to the hashmail user
    mapping(string hashmail => string[] itemIds) private hashmailToItems;

    // itemId => Item struct
    mapping(string itemId => Item) private items;

    // tokenId => Souvenir data
    mapping(uint256 tokenId => Souvenir souvenir) private souvenirData;

    // Event Definitions
    event ItemRegistered(string indexed itemId, string hashmail);
    event ItemTransferred(string indexed itemId, string fromHashmail, string toHashmail);
    event SouvenirMinted(uint256 indexed tokenId, string indexed itemId, string hashmail);
    event QuotaUpdated(string hashmail, uint32 totalMegabytes, uint32 usedMegabytes, uint16 totalNbSouvenirs, uint16 usedNbSouvenirs);
    event GuardiansUpdated(string indexed itemId, string[] guardians);
    event ItemMetadataUpdated(string indexed itemId, string metadata);
    event SouvenirMetadataUpdated(uint256 indexed tokenId, string metadata);

    constructor(
        string memory _baseItemUri,
        uint16 _defaultQuotaMegabytes,
        uint8 _defaultQuotaNbSouvenirs
    ) CustomERC721(_msgSender(), "Souvenirs by Lumissoly", "LUMISSOLY") {
        baseItemUri = _baseItemUri;
        _nextTokenId = 1;

        defaultQuotaMegabytes = _defaultQuotaMegabytes;
        defaultQuotaNbSouvenirs = _defaultQuotaNbSouvenirs;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Base URI for computing {tokenURI}.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseItemUri;
    }

    /**
     * @dev Allows the owner to adjust the default quotas for new items.
     */
    function setDefaultQuotas(uint16 _megabytes, uint8 _nbSouvenirs) external onlyOwner {
        defaultQuotaMegabytes = _megabytes;
        defaultQuotaNbSouvenirs = _nbSouvenirs;
    }

    /**
     * @dev Allows the owner to add additional quotas to a user's account.
     * The added quota must be positive.
     */
    function addUserQuota(
        string calldata hashmail,
        uint16 additionalMegabytes,
        uint8 additionalNbSouvenirs
    ) external onlyOwner {
        require(additionalMegabytes > 0 || additionalNbSouvenirs > 0, "Added quotas must be positive");
        Quota storage userQuota = hashmailToQuotas[hashmail];
        userQuota.totalMegabytes += additionalMegabytes;
        userQuota.totalNbSouvenirs += additionalNbSouvenirs;

        emit QuotaUpdated(
            hashmail,
            userQuota.totalMegabytes,
            userQuota.usedMegabytes,
            userQuota.totalNbSouvenirs,
            userQuota.usedNbSouvenirs
        );
    }

    uint8 public constant MUST_NOT_EXISTS = 0;
    uint8 public constant MUST_EXISTS = 1;
    modifier validItemID(string memory itemId, uint8 condition) {
        if (condition == MUST_EXISTS) {
            require(bytes(items[itemId].ownerHashmail).length >= 1, "Item not registered");
        }
        if (condition == MUST_NOT_EXISTS) {
            require(bytes(items[itemId].ownerHashmail).length == 0, "Item already registered");
        }
        require(strlen(itemId) == 32, "ItemID must be 32 HEX");
        _;
    }

    // Define the modifier to validate metadata format
    modifier validMetadata(string memory metadata) {
        bytes memory metadataBytes = bytes(metadata);

        if (metadataBytes.length > 0) {
            require(metadataBytes.length < 64000, "Metadata cannot exceed 64KB of data");

            uint16 colonCount = 0;
            for (uint16 i = 0; i < metadataBytes.length;) {
                if (metadataBytes[i] == ":") {
                    colonCount += 1;
                } else if (metadataBytes[i] == "|") {
                    // Each entry must contain exactly one colon before encountering '|'
                    require(colonCount == 1, "Each entry must contain exactly one ':' character");
                    colonCount = 0; // Reset colon count for the next entry
                }
                unchecked {i++;}
            }
            // Ensure the last entry had exactly one colon and no trailing '|'
            require(colonCount == 1, "Each entry must contain exactly one ':' character");
        }
        _;
    }

    /**
     * @dev Registers a new physical item (itemId) and assigns it to a hashmail user.
     * Increases the user's total quotas by the default values.
     */
    function registerItem(
        string calldata itemId,
        string calldata hashmail,
        string calldata metadata
    ) external onlyOwner validMetadata(metadata) validItemID(itemId, MUST_NOT_EXISTS) {
        // Initialize the item struct
        Item storage newItem = items[itemId];
        newItem.ownerHashmail = hashmail;
        newItem.metadata = metadata;

        // Add the itemId to the user's list
        hashmailToItems[hashmail].push(itemId);

        // Increase the user's total quotas by the default values
        Quota storage userQuota = hashmailToQuotas[hashmail];
        userQuota.totalMegabytes += defaultQuotaMegabytes;
        userQuota.totalNbSouvenirs += defaultQuotaNbSouvenirs;

        // Emit events
        emit ItemRegistered(itemId, hashmail);
        emit QuotaUpdated(
            hashmail,
            userQuota.totalMegabytes,
            userQuota.usedMegabytes,
            userQuota.totalNbSouvenirs,
            userQuota.usedNbSouvenirs
        );
        emit ItemMetadataUpdated(itemId, metadata);
    }

    /**
     * @dev Transfers an item from one hashmail user to another.
     * Adjusts quotas accordingly for both users.
     */
    function transferItem(string calldata itemId, string calldata toHashmail) external onlyOwner validItemID(itemId, MUST_EXISTS) {
        Item storage item = items[itemId];
        string memory fromHashmail = item.ownerHashmail;

        // Update ownership
        item.ownerHashmail = toHashmail;

        // Remove the item from the sender's list using loop-based search
        string[] storage fromItems = hashmailToItems[fromHashmail];
        bool found = false;
        uint8 fromLength = uint8(fromItems.length);
        for (uint8 i = 0; i < fromLength;) {
            if (keccak256(bytes(fromItems[i])) == keccak256(bytes(itemId))) {
                fromItems[i] = fromItems[fromItems.length - 1];
                fromItems.pop();
                found = true;
                break;
            }
            unchecked {i++;}
        }
        require(found, "Item not found in sender's list");

        // Add the item to the receiver's list
        hashmailToItems[toHashmail].push(itemId);

        // Adjust quotas
        uint16 souvenirCount = uint16(item.souvenirTokenIds.length);
        uint32 totalSizeInMB = 0;

        for (uint16 i = 0; i < souvenirCount;) {
            uint256 tokenId = item.souvenirTokenIds[i];
            totalSizeInMB += souvenirData[tokenId].size;
            unchecked {i++;}
        }

        // Decrease sender's used quotas
        Quota storage fromQuota = hashmailToQuotas[fromHashmail];
        fromQuota.usedNbSouvenirs -= souvenirCount;
        fromQuota.usedMegabytes -= totalSizeInMB;

        // Increase receiver's used quotas
        Quota storage toQuota = hashmailToQuotas[toHashmail];
        toQuota.usedNbSouvenirs += souvenirCount;
        toQuota.usedMegabytes += totalSizeInMB;

        // Emit events
        emit ItemTransferred(itemId, fromHashmail, toHashmail);
        emit QuotaUpdated(
            fromHashmail,
            fromQuota.totalMegabytes,
            fromQuota.usedMegabytes,
            fromQuota.totalNbSouvenirs,
            fromQuota.usedNbSouvenirs
        );
        emit QuotaUpdated(
            toHashmail,
            toQuota.totalMegabytes,
            toQuota.usedMegabytes,
            toQuota.totalNbSouvenirs,
            toQuota.usedNbSouvenirs
        );
    }

    /**
     * @dev Mints a new souvenir associated with an item.
     * Registers the souvenir size and uuid, adjusting the user's quotas accordingly.
     */
    function mintSouvenir(
        string calldata itemId,
        string calldata hashmail,
        string calldata uuid,
        uint16 sizeInMB,
        string calldata metadata
    ) external onlyOwner validItemID(itemId, MUST_EXISTS) validMetadata(metadata) {
        Item storage item = items[itemId];
        require(keccak256(bytes(item.ownerHashmail)) == keccak256(bytes(hashmail)), "Hashmail does not own the item");
        require(sizeInMB >= 1, "Size must be at least 1 MB");

        // Check if the user's quota allows minting another souvenir
        Quota storage userQuota = hashmailToQuotas[hashmail];
        require(userQuota.usedNbSouvenirs < userQuota.totalNbSouvenirs, "User's item quota exceeded");
        require(userQuota.usedMegabytes + sizeInMB <= userQuota.totalMegabytes, "User's megabytes quota exceeded");

        // Check and mark the UUID as minted
        require(!_mintedUUIDs[uuid], "UUID has already been minted");
        _mintedUUIDs[uuid] = true;

        // Generate a new tokenId
        uint256 tokenId = _nextTokenId++;

        // Mint the souvenir to the contract owner
        _safeMint(owner(), tokenId);

        // Prepare the token metadata URI
        _setTokenURI(tokenId, toString(tokenId));

        // Store the souvenir data
        souvenirData[tokenId] = Souvenir({
            tokenId: tokenId,
            size: sizeInMB,
            metadata: metadata
        });

        // Associate the souvenir with the item
        item.souvenirTokenIds.push(tokenId);

        // Update the user's used quotas
        userQuota.usedNbSouvenirs += 1;
        userQuota.usedMegabytes += uint32(sizeInMB);

        // Emit events
        emit SouvenirMinted(tokenId, itemId, hashmail);
        emit SouvenirMetadataUpdated(tokenId, metadata);
        emit QuotaUpdated(
            hashmail,
            userQuota.totalMegabytes,
            userQuota.usedMegabytes,
            userQuota.totalNbSouvenirs,
            userQuota.usedNbSouvenirs
        );
    }

    uint8 public constant MAX_GUARDIANS = 2;

    /**
     * @dev Adds a guardian to an item.
     * Maximum of 2 guardians per item.
     */
    function _addGuardian(string memory itemId, string memory guardianHashmail) internal {
        Item storage item = items[itemId];
        require(item.guardians.length < MAX_GUARDIANS, "Maximum of 2 guardians allowed");

        // Ensure the guardian is not already added
        uint8 currentGuardians = uint8(item.guardians.length);
        uint8 iterations = min(MAX_GUARDIANS, currentGuardians);
        for (uint8 i = 0; i < iterations;) {
            require(
                keccak256(bytes(item.guardians[i])) != keccak256(bytes(guardianHashmail)),
                "Guardian already added"
            );
            unchecked {i++;}
        }

        item.guardians.push(guardianHashmail);

        // Emit event
        emit GuardiansUpdated(itemId, item.guardians);
    }

    /**
     * @dev Adds multiple guardians to an item in one transaction.
     * Ensures that the total number of guardians does not exceed the maximum limit.
     */
    function addGuardians(string calldata itemId, string[] calldata guardianHashmails) external onlyOwner validItemID(itemId, MUST_EXISTS) {
        Item storage item = items[itemId];

        require(item.guardians.length < 2, "Maximum of 2 guardians allowed");
        uint8 guardiansToAdd = min(MAX_GUARDIANS - uint8(item.guardians.length), uint8(guardianHashmails.length));

        for (uint8 i = 0; i < guardiansToAdd;) {
            _addGuardian(itemId, guardianHashmails[i]);
            unchecked {i++;}
        }
    }

    /**
     * @dev Removes a guardian from an item.
     */
    function removeGuardian(string calldata itemId, string calldata guardianHashmail) external onlyOwner validItemID(itemId, MUST_EXISTS) {
        Item storage item = items[itemId];
        uint8 currentGuardians = uint8(item.guardians.length);
        bool found = false;

        for (uint8 i = 0; i < currentGuardians;) {
            if (keccak256(bytes(item.guardians[i])) == keccak256(bytes(guardianHashmail))) {
                item.guardians[i] = item.guardians[currentGuardians - 1];
                item.guardians.pop();
                emit GuardiansUpdated(itemId, item.guardians);
                found = true;
                break;
            }
            unchecked {i++;}
        }

        require(found, "Guardian not found");
    }

    /**
     * @dev Updates metadata for an item.
     * Ensures that metadata follows the specified format.
     */
    function setItemMetadata(string calldata itemId, string calldata metadata) external onlyOwner validItemID(itemId, MUST_EXISTS) validMetadata(metadata) {
        // Update metadata for the item
        items[itemId].metadata = metadata;

        // Emit event
        emit ItemMetadataUpdated(itemId, metadata);
    }

    /**
     * @dev Updates metadata for a souvenir.
     */
    function setSouvenirMetadata(uint256 tokenId, string calldata metadata) external onlyOwner validMetadata(metadata) {
        require(_exists(tokenId), "Souvenir does not exist");

        // Update souvenir metadata
        souvenirData[tokenId].metadata = metadata;

        // Emit event
        emit SouvenirMetadataUpdated(tokenId, metadata);
    }

    // Getter functions

    /**
     * @dev Retrieves the total and used quotas for a user.
     */
    function getQuota(string memory hashmail) external view returns (
        uint32 totalMegabytes,
        uint32 usedMegabytes,
        uint16 totalNbSouvenirs,
        uint16 usedNbSouvenirs
    ) {
        Quota memory quota = hashmailToQuotas[hashmail];
        return (quota.totalMegabytes, quota.usedMegabytes, quota.totalNbSouvenirs, quota.usedNbSouvenirs);
    }

    /**
     * @dev Retrieves the remaining quotas for a user.
     */
    function getRemainingQuota(string memory hashmail) external view returns (
        uint32 remainingMegabytes,
        uint16 remainingNbSouvenirs
    ) {
        Quota memory quota = hashmailToQuotas[hashmail];
        remainingMegabytes = quota.totalMegabytes - quota.usedMegabytes;
        remainingNbSouvenirs = quota.totalNbSouvenirs - quota.usedNbSouvenirs;
        return (remainingMegabytes, remainingNbSouvenirs);
    }

    /**
     * @dev Retrieves the items registered to a user.
     */
    function getItemsByHashmail(string memory hashmail) external view returns (string[] memory) {
        return hashmailToItems[hashmail];
    }

    /**
     * @dev Retrieves the owner of an item.
     */
    function getItemOwner(string memory itemId) external view returns (string memory) {
        return items[itemId].ownerHashmail;
    }

    /**
     * @dev Retrieves the guardians of an item.
     */
    function getItemGuardians(string memory itemId) external view returns (string[] memory) {
        return items[itemId].guardians;
    }

    /**
     * @dev Retrieves the souvenirs associated with an item.
     */
    function getItemSouvenirs(string memory itemId) external view returns (uint256[] memory) {
        return items[itemId].souvenirTokenIds;
    }

    /**
     * @dev Retrieves the number of souvenirs tied to an item.
     */
    function getItemSouvenirCount(string memory itemId) public view returns (uint16) {
        return uint16(items[itemId].souvenirTokenIds.length);
    }

    /**
     * @dev Retrieves metadata for an item.
     */
    function getItemMetadata(string memory itemId) external view returns (string memory) {
        return items[itemId].metadata;
    }

    /**
     * @dev Retrieves metadata for a souvenir.
     */
    function getSouvenirMetadata(uint256 tokenId) external view returns (string memory) {
        return souvenirData[tokenId].metadata;
    }

    /**
     * @dev Retrieves detailed information about a souvenir.
     */
    function getSouvenirInfo(uint256 tokenId) external view returns (
        uint256 tokenID,
        string memory metadata
    ) {
        require(_exists(tokenId), "Souvenir does not exist");

        Souvenir memory souvenir = souvenirData[tokenId];
        return (souvenir.tokenId, souvenir.metadata);
    }

    /**
     * @dev Retrieves the state of an item.
     */
    function getItemState(string calldata itemId) public view returns (ItemState) {
        Item memory item = items[itemId];
        // If the item is not registered by anyone
        if (bytes(item.ownerHashmail).length == 0) {
            return ItemState.NOT_REGISTERED;
        }

        // If the item have no guardians
        if (item.guardians.length == 0) {
            return ItemState.REGISTERED;
        }

        // If the item have no souvenirs
        if (item.souvenirTokenIds.length == 0) {
            return ItemState.WITH_GUARDIANS;
        }

        return ItemState.WITH_SOUVENIRS;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
    }
}