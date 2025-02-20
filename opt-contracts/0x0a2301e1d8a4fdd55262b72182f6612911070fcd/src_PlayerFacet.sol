// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot, Player} from "./src_AppStorage.sol";
import {AppModifiers} from "./src_AppModifiers.sol";
import {PlayerLibrary} from "./src_libraries_PlayerLibrary.sol";
import {EnergyLibrary} from "./src_libraries_EnergyLibrary.sol";

contract PlayerFacet is AppModifiers {
    event PlayerInitialized(address indexed player);
    event PlayerXPGained(address indexed player, uint256 amount);
    event PlayerLevelUp(address indexed player, uint256 newLevel);
    event RegenTicksUpdated(address indexed player, uint256 newTicks);

    error PlayerAlreadyInitialized();
    error PlayerNotInitialized();
    error InvalidXPAmount();

    struct EnergyInfo {
        uint256 currentEnergy;
        uint256 maxEnergy;
        uint256 timeToNextEnergy;
        uint256 timeToNextRefill;
    }

    function initializePlayer() external {
        if (s.addressToPlayer[msg.sender].isInitialized) {
            revert PlayerAlreadyInitialized();
        }

        s.addressToPlayer[msg.sender] = Player({
            xp: 0,
            level: 0,
            isInitialized: true,
            playerAddress: msg.sender,
            regenTick: 1
        });

        emit PlayerInitialized(msg.sender);
    }

    function getPlayer(address player) external view returns (Player memory) {
        return s.addressToPlayer[player];
    }

    function getMaxEnergy(address player) external view returns (uint256) {
        return PlayerLibrary.getMaxEnergy(player);
    }

    function getCurrentTicks(address player) external view returns (uint256) {
        return PlayerLibrary.getCurrentTicks(player);
    }

    function updateRegenTicks(address player) external {
        PlayerLibrary.updateRegenTicks(player);
        emit RegenTicksUpdated(player, PlayerLibrary.getCurrentTicks(player));
    }
    
    //P1 - Testing function
    function addXP(address player, uint256 amount) external {
        PlayerLibrary.addXP(player, amount);
        
        emit PlayerXPGained(player, amount);
    }

    function getEnergyInfo(address player) external view returns (EnergyInfo memory) {
        return EnergyInfo({
            currentEnergy: EnergyLibrary.calculateCurrentEnergy(player),
            maxEnergy: PlayerLibrary.getMaxEnergy(player),
            timeToNextEnergy: EnergyLibrary.timeToNextEnergy(player),
            timeToNextRefill: EnergyLibrary.timeToNextRefill(player)
        });
    }
}