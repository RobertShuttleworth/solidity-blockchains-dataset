// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {AppStorage} from "./src_AppStorage.sol";
import {console} from "./lib_forge-std_src_Test.sol";
import {RandoLibrary} from "./src_libraries_RandoLibrary.sol";
import {Village} from "./src_AppStorage.sol";
import {ResourceFacet} from "./src_ResourceFacet.sol";
import {AttackFacet} from "./src_AttackFacet.sol";

library VillagersLibrary {
    uint8 constant VILLAGERS_PER_HUT = 5;
    uint8 constant FOOD_PER_VILLAGER = 1;

    uint256 public constant STOKE_INTERVAL = 3 days;
    uint256 public constant CHOP_WOOD_INTERVAL = 6 hours;
    uint256 public constant GATHER_FOOD_INTERVAL = 3 hours;
    uint256 public constant ATTACK_INTERVAL = 6 hours;

    error NotThatManyVillagersAvailable();

    function initVillage(uint256 _tokenId, string memory name) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.tokenIdToVillage[_tokenId] = Village(
            _tokenId,
            name,
            msg.sender,
            block.timestamp,
            0,
            0,
            block.timestamp,
            0,
            block.timestamp - 6 hours,
            0,
            block.timestamp - 3 hours,
            0,
            0,
            0, //timeLastAttacked
            0, //timeLastAttackedBySomeone
            new uint256[](0),
            0, //level
            0, //villagers chopping
            0, //villagers gathering
            0, //timeLastSpeedUpChop
            0, //timeLastSpeedUpGather
            0, // villagersRaiding
            0, // villagersDefending
            0, // lastTimeUpdatedWood;
            0, // lumberCamps;
            0 // villagersInLumberCamp;
        );
    }

    function calculateFoodNeededForStoke(
        Village storage _village
    ) internal view returns (uint256) {
        uint256 foodNeeded = _village.villagers * FOOD_PER_VILLAGER; //will be 0 at first
        return foodNeeded;
    }

    function calculateAddedVillagers(
        uint256 _foodNeededForStoke,
        Village storage _village
    ) internal view returns (int256) {
        if (_village.food < _foodNeededForStoke) {
            int256 foodMissing = int256(_foodNeededForStoke) -
                int256(_village.food);
            int256 villagersLost = foodMissing / int8(FOOD_PER_VILLAGER) / 2; //lose half of the villagers

            return -villagersLost;
        } else {
            uint256 totalCapacity = _village.huts * VILLAGERS_PER_HUT;
            uint256 availableSpace = totalCapacity > _village.villagers
                ? totalCapacity - _village.villagers
                : 0;

            if (availableSpace == 0) {
                return 0;
            }

            uint256 leftOverFood = _village.food - _foodNeededForStoke;
            uint256 villagersToAdd = (leftOverFood / FOOD_PER_VILLAGER) / 2;
            return int256(min(availableSpace, villagersToAdd));
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function updateAllocations(Village storage _village) internal {
        if (
            block.timestamp - _village.timeLastChoppedWood >= CHOP_WOOD_INTERVAL
        ) {
            _village.villagersChopping = 0;
        }
        if (
            block.timestamp - _village.timeLastGatheredFood >=
            GATHER_FOOD_INTERVAL
        ) {
            _village.villagersGathering = 0;
        }
        if (block.timestamp - _village.timeLastAttacked >= ATTACK_INTERVAL) {
            _village.villagersRaiding = 0;
        }
    }

    function getAvailableVillagers(
        Village storage _village
    ) internal view returns (uint256) {
        return
            _village.villagers -
            _village.villagersChopping -
            _village.villagersGathering -
            _village.villagersInLumberCamp -
            _village.villagersRaiding -
            _village.villagersDefending;
    }
}