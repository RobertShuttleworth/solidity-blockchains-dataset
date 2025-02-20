// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {AppStorage} from "./src_AppStorage.sol";
import {Village, VillageReward} from "./src_AppStorage.sol";
import {console} from "./lib_forge-std_src_Test.sol";
import {VillagersLibrary} from "./src_libraries_VillagersLibrary.sol";

library WoodLibrary {
    uint256 constant PRECISION = 1 ether;

    //0.00001157407 wood per villager per second
    uint256 constant NUM_WOOD_PER_VILLAGER_PER_SEC = 1.157e13; // over 1000000000000000000

    event UpdateLumberCampWoodV2(uint256 tokenId, uint256 newWood); //wood change instead of it being the state

    function getWood(uint256 _tokenId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        Village memory village = s.tokenIdToVillage[_tokenId];
        return village.wood + getNewWoodFromLumberCamp(_tokenId, village);
    }

    function getNewWoodFromLumberCamp(
        uint256 _tokenId,
        Village memory village
    ) internal view returns (uint256) {
        uint256 timeWorking = 0; //if 0 then they have no one working
        if (village.lastTimeUpdatedWood > 0) {
            timeWorking = block.timestamp - village.lastTimeUpdatedWood;
        }

        uint256 newWood = (village.villagersInLumberCamp *
            NUM_WOOD_PER_VILLAGER_PER_SEC *
            timeWorking) / PRECISION;
        return newWood;
    }

    //update this before setting wood
    function updateLumberCampWood(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Village storage village = s.tokenIdToVillage[_tokenId];

        uint256 newWood = getNewWoodFromLumberCamp(_tokenId, village);
        if (newWood > 0) {
            village.wood += newWood;
            village.lastTimeUpdatedWood = block.timestamp; //keep track of when wood was last updated from auto collecting
            emit UpdateLumberCampWoodV2(_tokenId, newWood); //let our indexer know that wood has been updated
        }
    }
}