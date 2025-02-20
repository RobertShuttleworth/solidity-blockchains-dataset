// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {console} from "./lib_forge-std_src_Test.sol";
import {RandoLibrary} from "./src_libraries_RandoLibrary.sol";
import {Village} from "./src_AppStorage.sol";
import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {WoodLibrary} from "./src_libraries_WoodLibrary.sol";

library AttackLibrary {
    uint256 constant PRECISION = 1e18;
    uint256 constant MULTIPLIER = 3;

    function handleBattleResult(
        uint256 _seed,
        uint256 _winnerTokenId,
        uint256 _loserTokenId,
        uint16 _resourceToSteal,
        bool _isRandResourceToExchange
    ) internal returns (uint16, uint256) {
        Village storage winnerVillage = LibAppStorage
            .appStorage()
            .tokenIdToVillage[_winnerTokenId];
        Village storage loserVillage = LibAppStorage
            .appStorage()
            .tokenIdToVillage[_loserTokenId];

        //100 * 1e18 // == 1
        uint256 minRange = loserVillage.score * 15 * 1e18; // 0.15
        uint256 maxRange = loserVillage.score * 25 * 1e18; // 0.25
        if (_isRandResourceToExchange) {
            //if defense wins then the range of resources you lose is less
            minRange = loserVillage.score * 10 * 1e18; // 0.1
            maxRange = loserVillage.score * 15 * 1e18; //.15
        }

        uint256 randResourceLarge;
        if (maxRange - minRange == 0) {
            randResourceLarge = minRange;
        } else {
            randResourceLarge =
                (RandoLibrary.random(_seed) % (maxRange - minRange)) +
                minRange;
        }
        uint256 amountResource = randResourceLarge / (100 * 1e18);
        if (amountResource == 0) {
            //if defense
            if (_isRandResourceToExchange) {
                amountResource = 2;
            } else {
                amountResource = 3;
            }
        }

        uint16 resourceExchanged = _resourceToSteal;
        if (_isRandResourceToExchange) {
            resourceExchanged = uint16(RandoLibrary.random(_seed + 6) % 2); //0-1
        }

        // 0 = wood, 1 = food
        if (resourceExchanged == 0) {
            if (amountResource > WoodLibrary.getWood(loserVillage.villageId)) {
                amountResource = WoodLibrary.getWood(loserVillage.villageId);
            }

            WoodLibrary.updateLumberCampWood(winnerVillage.villageId);
            winnerVillage.wood += amountResource;
            WoodLibrary.updateLumberCampWood(loserVillage.villageId);
            loserVillage.wood -= amountResource;
        } else {
            if (amountResource > loserVillage.food) {
                amountResource = loserVillage.food;
            }

            winnerVillage.food += amountResource;
            loserVillage.food -= amountResource;
        }
        return (
            resourceExchanged, //the resource exchanged
            amountResource
        );
    }

    /*
    Battle Formula:
    Let R = raiders, D = defenders
    delta = R - D
    X = 2 * max(R, D)
    
    Victory condition:
    random(0..X) > (X/2 - delta)
    
    This gives raiders advantage when R > D,
    as delta becomes positive, making victory threshold lower
    */
    function simulateRaidersWin(
        uint256 _villagersRaiding,
        uint256 _villagersDefending,
        uint256 _seed
    ) public view returns (bool) {
        // Scale up the numbers before calculations
        uint256 scaledRaiders = _villagersRaiding * PRECISION;
        uint256 scaledDefenders = _villagersDefending * PRECISION;

        int256 delta = int256(scaledRaiders) - int256(scaledDefenders);
        uint256 maxVillagers = scaledRaiders > scaledDefenders
            ? scaledRaiders
            : scaledDefenders;
        uint256 X = MULTIPLIER * maxVillagers;

        uint256 randomNumber = RandoLibrary.random(_seed) % X;

        return int256(randomNumber) > int256(X / 2) - delta;
    }
}