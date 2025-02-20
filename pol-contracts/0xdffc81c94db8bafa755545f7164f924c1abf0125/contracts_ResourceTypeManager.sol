// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_AuthorizationModifiers.sol";

contract ResourceTypeManager is AuthorizationModifiers {
    
    struct ResourceType {
        string name;
        bool canBeCarriedBetweenStorages;
        bool canBeTransferredToGlobalMarketplace;
    }

    ResourceType[] public resourceTypes;
    mapping(string => uint256) private resourceTypeIndex;

    event ResourceTypeAdded(string name, bool canBeCarriedBetweenStorages, bool canBeTransferredToGlobalMarketplace);
    event ResourceTypeUpdated(string name, bool canBeCarriedBetweenStorages, bool canBeTransferredToGlobalMarketplace);
    event ResourceTypeRemoved(string name);

    constructor(
        address _centralAuthorizationRegistry       
    ) AuthorizationModifiers(_centralAuthorizationRegistry, keccak256("IResourceTypeManager")) {
        _addResourceType("coconut", true, true);
        _addResourceType("citrus", true, true);
        _addResourceType("fish", true, true);
        _addResourceType("tobacco", true, true);
        _addResourceType("cotton", true, true);
        _addResourceType("pig", true, true);
        _addResourceType("wood", true, true);
        _addResourceType("sugarcane", true, true);
        _addResourceType("grain", true, true);
        _addResourceType("planks", true, true);
        _addResourceType("meat", true, true); // New resource type
        _addResourceType("barrel-packed fish", true, true); // New resource type
        _addResourceType("barrel-packed meat", true, true); // New resource type
        _addResourceType("crates", true, true); // New resource type
        _addResourceType("barrels", true, true); // New resource type
        _addResourceType("bags", true, true); // New resource type
        _addResourceType("bag-packed tobacco", true, true); // New resource type
        _addResourceType("bag-packed grain", true, true); // New resource type
        _addResourceType("bag-packed cotton", true, true); // New resource type
        _addResourceType("bag-packed sugarcane", true, true); // New resource type
        _addResourceType("wild game", true, true); // New resource type
        _addResourceType("coconut liquor", true, true); // New resource type
        _addResourceType("crate-packed citrus", true, true); // New resource type
        _addResourceType("crate-packed coconuts", true, true); // New resource type
        _addResourceType("stone", true, true); // New resource type
        _addResourceType("bricks", true, true); // New resource type
        _addResourceType("gold bars", true, true); // New resource type
    }

    function addResourceType(
        string memory name,
        bool canBeCarriedBetweenStorages,
        bool canBeTransferredToGlobalMarketplace
    ) public onlyAdmin {
        _addResourceType(name, canBeCarriedBetweenStorages, canBeTransferredToGlobalMarketplace);
    }

    function _addResourceType(
        string memory name,
        bool canBeCarriedBetweenStorages,
        bool canBeTransferredToGlobalMarketplace
    ) internal {
        require(resourceTypeIndex[name] == 0, "Resource type already exists");

        resourceTypes.push(ResourceType(name, canBeCarriedBetweenStorages, canBeTransferredToGlobalMarketplace));
        resourceTypeIndex[name] = resourceTypes.length;

        emit ResourceTypeAdded(name, canBeCarriedBetweenStorages, canBeTransferredToGlobalMarketplace);
    }

    function updateResourceType(
        string memory name,
        bool canBeCarriedBetweenStorages,
        bool canBeTransferredToGlobalMarketplace
    ) public onlyAdmin {
        uint256 index = resourceTypeIndex[name];
        require(index > 0, "Resource type does not exist");

        resourceTypes[index - 1] = ResourceType(name, canBeCarriedBetweenStorages, canBeTransferredToGlobalMarketplace);

        emit ResourceTypeUpdated(name, canBeCarriedBetweenStorages, canBeTransferredToGlobalMarketplace);
    }

    function removeResourceType(string memory name) public onlyAdmin {
        uint256 index = resourceTypeIndex[name];
        require(index > 0, "Resource type does not exist");

        uint256 lastIndex = resourceTypes.length - 1;
        if (index - 1 != lastIndex) {
            ResourceType memory lastResourceType = resourceTypes[lastIndex];
            resourceTypes[index - 1] = lastResourceType;
            resourceTypeIndex[lastResourceType.name] = index;
        }

        resourceTypes.pop();
        delete resourceTypeIndex[name];

        emit ResourceTypeRemoved(name);
    }

    function getResourceTypes() external view returns (ResourceType[] memory) {
        return resourceTypes;
    }

    function isValidResourceType(string memory name) public view returns (bool) {
        return resourceTypeIndex[name] > 0;
    }

    function getResourceTypeNames() external view returns (string[] memory) {
        string[] memory names = new string[](resourceTypes.length);
        for (uint256 i = 0; i < resourceTypes.length; i++) {
            names[i] = resourceTypes[i].name;
        }
        return names;
    }
}