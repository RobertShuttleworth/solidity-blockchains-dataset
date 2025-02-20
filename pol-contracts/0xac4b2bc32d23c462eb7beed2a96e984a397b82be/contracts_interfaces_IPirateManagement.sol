// End Generation Here

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IPirateManagement {
    enum SkillType { Character, Tools, Special }
    enum CharacterSkill { Strength, Stamina, Swimming, Melee, Shooting, Cannons, Agility, Engineering, Wisdom, Luck, Health, Speed }
    enum ToolsSkill { Harvest, Mining, Quarrying, Excavation, Husbandry, Woodcutting, Slaughter, Hunting, Cultivation }
    enum SpecialSkill { FruitPicking, Fishing, Crafting, Building }

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
        bool added;
    }

    struct TokenSkillSet {
        uint256[] tokenIds;
        PirateSkills skills;
    }

    function getPirateSkills(address collectionAddress, uint256 tokenId) external view returns (PirateSkills memory);
    function batchUpdatePirateAttributes(address collectionAddress, TokenSkillSet[] calldata tokenSkillSets) external;
    function addSkillSet(PirateSkills calldata newSkills) external returns (uint256);
    function upgradeSkillSet(address collectionAddress, uint256 tokenId, PirateSkills calldata newSkills) external returns (uint256);
    function updateSingleSkill(address collectionAddress, uint256 tokenId, SkillType skillType, uint256 skillIndex, int256 value, bool isAddition) external;
}