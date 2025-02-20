// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot, Village, AttackDecision} from "./src_AppStorage.sol";
import {AppModifiers} from "./src_AppModifiers.sol";
import {console} from "./lib_forge-std_src_Test.sol";
import {RandoLibrary} from "./src_libraries_RandoLibrary.sol";
import {AttackLibrary} from "./src_libraries_AttackLibrary.sol";
import {DefendFacet} from "./src_DefendFacet.sol";
import {VillagersLibrary} from "./src_libraries_VillagersLibrary.sol";

contract AttackFacet is AppStorageRoot, AppModifiers {
    event AttackVillage(
        uint256 attackerVillageId,
        uint256 targetVillageId,
        uint16 resourceToSteal
    );
    event AttackVillageV2(
        uint256 attackerVillageId,
        uint256 targetVillageId,
        uint16 numVillagersRaidWood,
        uint16 numVillagersRaidFood
    );

    error AttackTimeHasNotPassed();
    error YouHaveAlreadyMadeAnAttack(uint256 villageId);
    error VillageHasAlreadyBeenAttacked();
    error VillageAlreadyAttackedInTheInterval();
    error VillageLevelTooLowForBattle();
    error VillageLevelTooHighForBattle();
    error CantRaidWithBothNoVillagers();
    error NotEnoughVillagersSentForNoDefense();

    function attackVillage(
        uint256 _attackerVillageId,
        uint256 _defenderVillageId,
        uint16 _resourceToSteal,
        uint256 _seed
    )
        external
        onlyVillageOwner(_attackerVillageId)
        onlyPlayersThatHaveRevealed(_attackerVillageId)
        onlyNonRazedVillages(_attackerVillageId)
    {
        Village storage defenderVillage = s.tokenIdToVillage[
            _defenderVillageId
        ];

        if (
            block.timestamp - defenderVillage.timeLastAttackedBySomeone <
            VillagersLibrary.ATTACK_INTERVAL
        ) {
            revert VillageAlreadyAttackedInTheInterval();
        }

        Village storage attackerVillage = s.tokenIdToVillage[
            _attackerVillageId
        ];

        if (defenderVillage.level > 2) {
            revert VillageLevelTooHighForBattle();
        }

        if (
            block.timestamp - attackerVillage.timeLastAttacked <
            VillagersLibrary.ATTACK_INTERVAL
        ) {
            revert AttackTimeHasNotPassed();
        }

        //defender has not set their defense, so use random number
        if (s.tokenIdToStoredHash[_defenderVillageId] == bytes32(0)) {
            uint resourceExchanged = 0;
            uint amountResource = 0;
            uint256 randomNum = (RandoLibrary.random(_seed) % 100) + 1; //1-100
            //65% chance of winning
            bool isAttackerWin = randomNum <= 65;
            if (isAttackerWin) {
                //attacker wins
                (resourceExchanged, amountResource) = AttackLibrary
                    .handleBattleResult(
                        _seed,
                        _attackerVillageId,
                        _defenderVillageId,
                        _resourceToSteal,
                        false
                    );
                _emitRevealBattleResult(
                    _attackerVillageId,
                    _defenderVillageId,
                    _attackerVillageId,
                    resourceExchanged,
                    amountResource
                );
            } else {
                _emitRevealBattleResult(
                    _attackerVillageId,
                    _defenderVillageId,
                    _defenderVillageId,
                    0,
                    0 //no resources exchanged in this case
                );
            }
        } else {
            //setup the attack decision for later
            AttackDecision storage attackDecision = s
                .defenderIdAndAttackerIdToAttackDecision[
                    string(
                        abi.encodePacked(
                            _defenderVillageId,
                            "-",
                            _attackerVillageId
                        )
                    )
                ];

            //not needed because already reverts above
            // if (attackDecision.timeAttacked != 0) {
            //     revert YouHaveAlreadyMadeAnAttack(_attackerVillageId);
            // }

            attackDecision.resourceToSteal = _resourceToSteal;
            attackDecision.timeAttacked = block.timestamp;
            defenderVillage.attackedByVillageIds.push(_attackerVillageId); //push on the latest attacker that needs to be revealed
        }
        attackerVillage.timeLastAttacked = block.timestamp;
        attackerVillage.villagersRaiding = 0;
        defenderVillage.timeLastAttackedBySomeone = block.timestamp;

        emit AttackVillage(
            _attackerVillageId,
            _defenderVillageId,
            _resourceToSteal
        );
    }

    function attackVillageV2(
        uint256 _attackerVillageId,
        uint256 _defenderVillageId,
        uint16 _numVillagersRaidWood,
        uint16 _numVillagersRaidFood,
        uint256 _seed
    )
        external
        onlyVillageOwner(_attackerVillageId)
        onlyPlayersThatHaveRevealed(_attackerVillageId)
        onlyNonRazedVillages(_attackerVillageId)
    {
        Village storage defenderVillage = s.tokenIdToVillage[
            _defenderVillageId
        ];

        if (
            block.timestamp - defenderVillage.timeLastAttackedBySomeone <
            VillagersLibrary.ATTACK_INTERVAL
        ) {
            revert VillageAlreadyAttackedInTheInterval();
        }

        Village storage attackerVillage = s.tokenIdToVillage[
            _attackerVillageId
        ];

        if (defenderVillage.level < 3) {
            revert VillageLevelTooLowForBattle();
        }

        if (
            block.timestamp - attackerVillage.timeLastAttacked <
            VillagersLibrary.ATTACK_INTERVAL
        ) {
            revert AttackTimeHasNotPassed();
        }

        VillagersLibrary.updateAllocations(attackerVillage);
        if (
            VillagersLibrary.getAvailableVillagers(attackerVillage) <
            _numVillagersRaidWood + _numVillagersRaidFood
        ) {
            revert VillagersLibrary.NotThatManyVillagersAvailable();
        }
        if (_numVillagersRaidWood == 0 && _numVillagersRaidFood == 0) {
            revert CantRaidWithBothNoVillagers();
        }

        //defender has not set their defense, so use random number
        if (s.tokenIdToStoredHash[_defenderVillageId] == bytes32(0)) {
            _handleRandomResult(
                _attackerVillageId,
                _defenderVillageId,
                _numVillagersRaidWood,
                _numVillagersRaidFood,
                _seed
            );
        } else {
            //setup the attack decision for later
            AttackDecision storage attackDecision = s
                .defenderIdAndAttackerIdToAttackDecision[
                    string(
                        abi.encodePacked(
                            _defenderVillageId,
                            "-",
                            _attackerVillageId
                        )
                    )
                ];

            attackDecision.timeAttacked = block.timestamp;
            attackDecision.numVillagersRaidWood = _numVillagersRaidWood;
            attackDecision.numVillagersRaidFood = _numVillagersRaidFood;
            defenderVillage.attackedByVillageIds.push(_attackerVillageId); //push on the latest attacker that needs to be revealed
        }
        attackerVillage.timeLastAttacked = block.timestamp;
        attackerVillage.villagersRaiding =
            _numVillagersRaidWood +
            _numVillagersRaidFood;
        defenderVillage.timeLastAttackedBySomeone = block.timestamp;

        emit AttackVillageV2(
            _attackerVillageId,
            _defenderVillageId,
            _numVillagersRaidWood,
            _numVillagersRaidFood
        );
    }

    function _handleRandomResult(
        uint256 _attackerVillageId,
        uint256 _defenderVillageId,
        uint16 _numVillagersRaidWood,
        uint16 _numVillagersRaidFood,
        uint256 _seed
    ) internal {
        Village memory attackerVillage = s.tokenIdToVillage[_attackerVillageId];
        if (
            (_numVillagersRaidWood > 0 &&
                _numVillagersRaidWood <
                (attackerVillage.villagers * 20) / 100) ||
            (_numVillagersRaidFood > 0 &&
                _numVillagersRaidFood < (attackerVillage.villagers * 20) / 100)
        ) {
            revert NotEnoughVillagersSentForNoDefense();
        }

        bool isAttackerWin = false; //defense shows as a win if there is no attack as well
        bool isAttackerWin2 = false;
        uint amountWood = 0;
        uint amountFood = 0;
        if (_numVillagersRaidWood > 0) {
            uint256 randomNum = (RandoLibrary.random(_seed) % 100) + 1; //1-100
            //75% chance of winning
            isAttackerWin = randomNum <= 75;
            //for wood first
            amountWood = _attackHelper(
                isAttackerWin,
                _attackerVillageId,
                _defenderVillageId,
                0, //for wood
                _seed
            );
        }

        if (_numVillagersRaidFood > 0) {
            uint256 randomNum2 = (RandoLibrary.random(_seed + 1) % 100) + 1; //1-100
            //55% chance of winning
            isAttackerWin2 = randomNum2 <= 55;
            amountFood = _attackHelper(
                isAttackerWin2,
                _attackerVillageId,
                _defenderVillageId,
                1, //for food
                _seed
            );
        }
        _emitRevealBattleResultV2(
            _attackerVillageId,
            _defenderVillageId,
            isAttackerWin ? _attackerVillageId : _defenderVillageId,
            isAttackerWin2 ? _attackerVillageId : _defenderVillageId,
            amountWood,
            amountFood
        );
    }

    function _attackHelper(
        bool _isAttackerWin,
        uint256 _attackerVillageId,
        uint256 _defenderVillageId,
        uint16 _resourceToSteal,
        uint256 _seed
    ) internal returns (uint256) {
        uint256 amountResource;
        if (_isAttackerWin) {
            //attacker wins
            (, amountResource) = AttackLibrary.handleBattleResult(
                _seed,
                _attackerVillageId,
                _defenderVillageId,
                _resourceToSteal,
                false
            );
        } else {
            //defender wins
            (, amountResource) = AttackLibrary.handleBattleResult(
                _seed,
                _defenderVillageId,
                _attackerVillageId,
                _resourceToSteal,
                false
            );
        }
        return amountResource;
    }

    function _emitRevealBattleResult(
        uint256 attackerVillageId,
        uint256 defenderVillageId,
        uint256 winnerVillageId,
        uint256 resourceExchanged,
        uint256 amountResource
    ) private {
        uint256[] memory attackerVillageIds = new uint256[](1);
        attackerVillageIds[0] = attackerVillageId;
        uint256[] memory winnerVillageIds = new uint256[](1);
        winnerVillageIds[0] = winnerVillageId;
        uint256[] memory resourcesExchanged = new uint256[](1);
        resourcesExchanged[0] = resourceExchanged;
        uint256[] memory amountResources = new uint256[](1);
        amountResources[0] = amountResource;

        emit DefendFacet.RevealBattleResult(
            attackerVillageIds,
            defenderVillageId,
            winnerVillageIds,
            resourcesExchanged,
            amountResources
        );
    }

    function _emitRevealBattleResultV2(
        uint256 attackerVillageId,
        uint256 defenderVillageId,
        uint256 woodWinnerVillageId,
        uint256 foodWinnerVillageId,
        uint256 wood,
        uint256 food
    ) private {
        uint256[] memory attackerVillageIds = new uint256[](1);
        attackerVillageIds[0] = attackerVillageId;
        uint256[] memory woodWinnerVillageIds = new uint256[](1);
        woodWinnerVillageIds[0] = woodWinnerVillageId;
        uint256[] memory foodWinnerVillageIds = new uint256[](1);
        foodWinnerVillageIds[0] = foodWinnerVillageId;
        uint256[] memory woodExchanged = new uint256[](1);
        woodExchanged[0] = wood;
        uint256[] memory foodExchanged = new uint256[](1);
        foodExchanged[0] = food;

        emit DefendFacet.RevealBattleResultV2(
            attackerVillageIds,
            defenderVillageId,
            woodWinnerVillageIds,
            foodWinnerVillageIds,
            woodExchanged,
            foodExchanged
        );
    }
}