// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// `AppStorageRoot` contract ensures AppStorage is at slot 0 for facets that inherit other contracts with storage.
// For example, ERC20 and ERC1155 facets inherit storage from the OZ templates.
// This causes AppStorage to NOT be at slot 0 where it should be. The AppStorage for those facets was separated
// from the diamond and in a different slot. Therefore, if we inherit `AppStorageRoot` as the FIRST inheritance,
// this forces AppStorage to be at slot 0 for the facet, and we can still have the extra storage afterwards.
// Note: This is a band-aid, and should not be used in production. For facets, you should probably lean towards
// not inheriting any contract that has storage itself (OZ templates, etc.), but rather extract what it does manually?
abstract contract AppStorageRoot {
    AppStorage internal s;
}


struct Gotchi {
    uint256 gotchiId;
    address owner;
    uint256 lastChargeTime;
    uint256 deathTime;
    uint256 xp;
    uint256 level;
    bool isDead;
}


struct Player {
    uint256 xp;
    uint256 level;
    bool isInitialized;
    address playerAddress;
    uint256 regenTick;
}



// // [Clankermon]
// struct AppStorage {
//     address clankermon;
//     mapping(uint256 => Gotchi) tokenIdToGotchi;
//     mapping(address => uint256) addressToEnergy;
//     uint256 nextTokenId;
//     string baseURI;
//     mapping(uint256 => address) tokenApprovals;
//     mapping(address => mapping(address => bool)) operatorApprovals;
//     mapping(address => uint256) lastEnergyUpdate;

//     // mapping(address => bool) addressToCanMint;
//     mapping(address => Player) addressToPlayer;
//     mapping(address => uint256) lastEnergyRefill;
// }

struct AppStorage {
    address stokeFireNFTAddress;
    uint256 totalVillageScore;
    mapping(uint256 => Village) tokenIdToVillage;
    mapping(address => bool) addressToCanMint;
    mapping(uint256 => bytes32) tokenIdToStoredHash;
    mapping(string => AttackDecision) defenderIdAndAttackerIdToAttackDecision; // defenderIdVillageId-attackerIdVillageId
    address fireAddress;
    uint256 fireCostOnStoke;
    uint256 blockTimeSwitchToNewRewards;
    uint256 totalVillageScoreAtSwitch;
    uint256 balanceAtSwitch;
    uint256 ethAccPerScore; //keeps track of current eth per score
    mapping(uint256 => VillageReward) tokenIdToVillageReward;
    address forwardFireAddress;
    uint256 fireCostOnSpeedUp;
    mapping(address => uint256) addressToInvitedByVillage;
    mapping(address => InviteClaimables) addressToInviteClaimables;
    mapping(address => uint256) addressToTokenId; //ensure only one village per address
    mapping(uint256 => Gotchi) tokenIdToGotchi;
    mapping(address => uint256) addressToEnergy;
    uint256 nextTokenId;
    string baseURI;
    mapping(uint256 => address) tokenApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;
    mapping(address => uint256) lastEnergyUpdate;
    address clankermon;
    mapping(address => Player) addressToPlayer;
    mapping(address => uint256) lastEnergyRefill;
}

// Example struct placed inside of AppStorage, "protected" with a mapping.
// Note: Do not nest structs unless you will never add more state variables to the inner struct.
// Note: You can't add new state vars to inner structs in upgrades without overwriting existing state vars.
// Note: It's recommended, but not mandatory, to place this within a mapping inside AppStorage to solve that issue.
// Note: Read exhaustive security concerns here: https://eip2535diamonds.substack.com/p/diamond-upgrades
struct Village {
    uint256 villageId;
    string name;
    address owner;
    uint256 timeMinted;
    uint256 timeRazed;
    uint256 score;
    uint256 timeFireLastStoked;
    uint256 wood;
    uint256 timeLastChoppedWood;
    uint256 food;
    uint256 timeLastGatheredFood;
    uint256 huts;
    uint256 villagers;
    uint256 timeLastAttacked;
    uint256 timeLastAttackedBySomeone;
    uint256[] attackedByVillageIds;
    uint32 level;
    uint256 villagersChopping;
    uint256 villagersGathering;
    uint256 timeLastSpeedUpChop;
    uint256 timeLastSpeedUpGather;
    uint256 villagersRaiding;
    uint256 villagersDefending;
    uint256 lastTimeUpdatedWood;
    uint256 lumberCamps;
    uint256 villagersInLumberCamp;
}

struct AttackDecision {
    uint16 resourceToSteal;
    uint256 timeAttacked;
    uint256 numVillagersRaidWood;
    uint256 numVillagersRaidFood;
}

struct VillageReward {
    uint256 debt;
    uint256 ethOwed;
}

struct InviteClaimables {
    uint256 woodToClaim;
    uint256 foodToClaim;
}
