// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./hardhat_console.sol";
import "./contracts_AuthorizationModifiers.sol";
import "./openzeppelin_contracts_utils_Strings.sol";


contract PirateManagement is AuthorizationModifiers {
    enum SkillType { Character, Tools, Special }
    enum CharacterSkill { Strength, Stamina, Swimming, Melee, Shooting, Cannons, Agility, Engineering, Wisdom, Luck, Health, Speed }
    enum ToolsSkill { Harvest, Mining, Quarrying, Excavation, Husbandry, Woodcutting, Slaughter, Hunting, Cultivation }
    enum SpecialSkill { FruitPicking, Fishing, Crafting, Building }

    // CharacterSkills 

    struct CharacterSkills {
        uint256 strength;
        uint256 stamina;
        uint256 swimming;
        uint256 melee;
        uint256 shooting;
        uint256 cannons;
        uint256 agility;
        uint256 engineering;
        uint256 wisdom;
        uint256 luck;
        uint256 health;
        uint256 speed;
    }

    //ToolsSkills

    struct ToolsSkills {
        uint256 harvest;
        uint256 mining;
        uint256 quarrying;
        uint256 excavation;
        uint256 husbandry;
        uint256 woodcutting;
        uint256 slaughter;
        uint256 hunting;
        uint256 cultivation;
    }

    // SpecialSkills

    struct SpecialSkills {
        uint256 fruitPicking;
        uint256 fishing;
        uint256 building;
        uint256 crafting;
    }

    struct PirateSkills {
        CharacterSkills characterSkills;
        ToolsSkills toolsSkills;
        SpecialSkills specialSkills;
        bool added; // Flag to indicate if the skill set has been updated
    }

    struct TokenSkillSet {
        uint256[] tokenIds;
        PirateSkills skills;
    }

    mapping(uint256 => PirateSkills) public skillSets;
    mapping(address => mapping(uint256 => uint256)) public pirateSkillSetIds;
    mapping(address => mapping(uint256 => PirateSkills)) public updatedSkillSets;
    mapping(bytes32 => uint256) private skillSetHashes;

    uint256 public nextSkillSetId = 1; // Start from 1 to avoid confusion with default value 0

    constructor(address _centralAuthorizationRegistry) AuthorizationModifiers(_centralAuthorizationRegistry, keccak256("IPirateManagement")) {                
    }

    function _getPirateSkills(address collectionAddress, uint256 tokenId) internal view returns (PirateSkills memory) {
        if (updatedSkillSets[collectionAddress][tokenId].added) {
            return updatedSkillSets[collectionAddress][tokenId];
        } else {
            uint256 skillSetId = pirateSkillSetIds[collectionAddress][tokenId];
            return skillSets[skillSetId];
        }
    }

    function getPirateSkills(address collectionAddress, uint256 tokenId) external view returns (PirateSkills memory) {
        return _getPirateSkills(collectionAddress, tokenId);
    }

    function getManyPirateSkills(address collectionAddress, uint256[] calldata tokenIds) external view returns (PirateSkills[] memory) {
        PirateSkills[] memory skills = new PirateSkills[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            skills[i] = _getPirateSkills(collectionAddress, tokenIds[i]);
        }
        return skills;
    }

    function batchUpdatePirateAttributes(address collectionAddress, TokenSkillSet[] calldata tokenSkillSets) external onlyAdmin {
        for (uint256 i = 0; i < tokenSkillSets.length; i++) {
            uint256 skillSetId = _getOrAddSkillSet(tokenSkillSets[i].skills);            
            
            for (uint256 j = 0; j < tokenSkillSets[i].tokenIds.length; j++) {
                pirateSkillSetIds[collectionAddress][tokenSkillSets[i].tokenIds[j]] = skillSetId;
            }
        }
    }

    function upgradeSkillSet(address collectionAddress, uint256 tokenId, PirateSkills calldata newSkills) external onlyAuthorized returns (uint256) {
        uint256 newSkillSetId = nextSkillSetId++;
        skillSets[newSkillSetId] = newSkills;
        pirateSkillSetIds[collectionAddress][tokenId] = newSkillSetId;
        return newSkillSetId;
    }

    function updateSingleSkill(address collectionAddress, uint256 tokenId, SkillType skillType, uint256 skillIndex, int256 value, bool isAddition) external onlyAuthorized {
        PirateSkills storage currentSkills = updatedSkillSets[collectionAddress][tokenId];

        if (skillType == SkillType.Character) {
            CharacterSkill characterSkill = CharacterSkill(skillIndex);
            if (characterSkill == CharacterSkill.Strength) currentSkills.characterSkills.strength = _updateSkillValue(currentSkills.characterSkills.strength, value, isAddition);
            else if (characterSkill == CharacterSkill.Stamina) currentSkills.characterSkills.stamina = _updateSkillValue(currentSkills.characterSkills.stamina, value, isAddition);
            else if (characterSkill == CharacterSkill.Swimming) currentSkills.characterSkills.swimming = _updateSkillValue(currentSkills.characterSkills.swimming, value, isAddition);
            else if (characterSkill == CharacterSkill.Melee) currentSkills.characterSkills.melee = _updateSkillValue(currentSkills.characterSkills.melee, value, isAddition);
            else if (characterSkill == CharacterSkill.Shooting) currentSkills.characterSkills.shooting = _updateSkillValue(currentSkills.characterSkills.shooting, value, isAddition);
            else if (characterSkill == CharacterSkill.Cannons) currentSkills.characterSkills.cannons = _updateSkillValue(currentSkills.characterSkills.cannons, value, isAddition);
            else if (characterSkill == CharacterSkill.Agility) currentSkills.characterSkills.agility = _updateSkillValue(currentSkills.characterSkills.agility, value, isAddition);
            else if (characterSkill == CharacterSkill.Engineering) currentSkills.characterSkills.engineering = _updateSkillValue(currentSkills.characterSkills.engineering, value, isAddition);
            else if (characterSkill == CharacterSkill.Wisdom) currentSkills.characterSkills.wisdom = _updateSkillValue(currentSkills.characterSkills.wisdom, value, isAddition);
            else if (characterSkill == CharacterSkill.Luck) currentSkills.characterSkills.luck = _updateSkillValue(currentSkills.characterSkills.luck, value, isAddition);
            else if (characterSkill == CharacterSkill.Health) currentSkills.characterSkills.health = _updateSkillValue(currentSkills.characterSkills.health, value, isAddition);
            else if (characterSkill == CharacterSkill.Speed) currentSkills.characterSkills.speed = _updateSkillValue(currentSkills.characterSkills.speed, value, isAddition);
        } else if (skillType == SkillType.Tools) {
            ToolsSkill toolsSkill = ToolsSkill(skillIndex);
            if (toolsSkill == ToolsSkill.Harvest) currentSkills.toolsSkills.harvest = _updateSkillValue(currentSkills.toolsSkills.harvest, value, isAddition);
            else if (toolsSkill == ToolsSkill.Mining) currentSkills.toolsSkills.mining = _updateSkillValue(currentSkills.toolsSkills.mining, value, isAddition);
            else if (toolsSkill == ToolsSkill.Quarrying) currentSkills.toolsSkills.quarrying = _updateSkillValue(currentSkills.toolsSkills.quarrying, value, isAddition);
            else if (toolsSkill == ToolsSkill.Excavation) currentSkills.toolsSkills.excavation = _updateSkillValue(currentSkills.toolsSkills.excavation, value, isAddition);
            else if (toolsSkill == ToolsSkill.Husbandry) currentSkills.toolsSkills.husbandry = _updateSkillValue(currentSkills.toolsSkills.husbandry, value, isAddition);
            else if (toolsSkill == ToolsSkill.Woodcutting) currentSkills.toolsSkills.woodcutting = _updateSkillValue(currentSkills.toolsSkills.woodcutting, value, isAddition);
            else if (toolsSkill == ToolsSkill.Slaughter) currentSkills.toolsSkills.slaughter = _updateSkillValue(currentSkills.toolsSkills.slaughter, value, isAddition);
            else if (toolsSkill == ToolsSkill.Hunting) currentSkills.toolsSkills.hunting = _updateSkillValue(currentSkills.toolsSkills.hunting, value, isAddition);
            else if (toolsSkill == ToolsSkill.Cultivation) currentSkills.toolsSkills.cultivation = _updateSkillValue(currentSkills.toolsSkills.cultivation, value, isAddition);
        } else if (skillType == SkillType.Special) {
            SpecialSkill specialSkill = SpecialSkill(skillIndex);
            if (specialSkill == SpecialSkill.FruitPicking) currentSkills.specialSkills.fruitPicking = _updateSkillValue(currentSkills.specialSkills.fruitPicking, value, isAddition);
            else if (specialSkill == SpecialSkill.Fishing) currentSkills.specialSkills.fishing = _updateSkillValue(currentSkills.specialSkills.fishing, value, isAddition);
            else if (specialSkill == SpecialSkill.Crafting) currentSkills.specialSkills.crafting = _updateSkillValue(currentSkills.specialSkills.crafting, value, isAddition);
            else if (specialSkill == SpecialSkill.Building) currentSkills.specialSkills.building = _updateSkillValue(currentSkills.specialSkills.building, value, isAddition);
        }

        currentSkills.added = true; // Mark the skill set as updated
    }

    function _updateSkillValue(uint256 currentValue, int256 value, bool isAddition) internal pure returns (uint256) {
        int256 newValue;
        if (isAddition) {
            newValue = int256(currentValue) + value;
        } else {
            newValue = int256(currentValue) - value;
        }
        require(newValue >= 0, "Skill value cannot be negative");
        return uint256(newValue);
    }
    function _getOrAddSkillSet(PirateSkills memory newSkills) internal returns (uint256) {
        bytes32 hash_value = keccak256(abi.encode(newSkills));
        uint256 skillSetId = skillSetHashes[hash_value];

        if (skillSetId == 0) {
            nextSkillSetId++;
            skillSetId = nextSkillSetId;
            skillSets[skillSetId] = newSkills;
            skillSetHashes[hash_value] = skillSetId;           
        }

        return skillSetId;
    }
}