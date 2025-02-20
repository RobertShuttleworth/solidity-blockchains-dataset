// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {AppStorage, Player} from "./src_AppStorage.sol";

// Add interface for Clankermon token
interface IClankermon {
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title PlayerLibrary
 * @notice Core logic for player progression and energy management
 * @dev Implements level-based system affecting energy caps
 *
 * Functions:
 * - calculateLevel(uint256): Calculate level from XP
 * - getMaxEnergy(address): Get max energy based on level
 * - addXP(address, uint256): Add XP and update level
 *
 * Constants:
 * - XP thresholds for levels 0-2
 * - Energy caps for levels 0-2
 */
library PlayerLibrary {
    // Events
    event PlayerXPGained(address indexed player, uint256 amount, uint256 newLevel);
    
    // Custom errors
    error PlayerNotInitialized();
    error InvalidXPAmount();

    // XP thresholds for each level [Player LVL XP Tiers]
    uint256 constant XP_LEVEL_1 = 100;
    uint256 constant XP_LEVEL_2 = 250;
    uint256 constant XP_LEVEL_3 = 500;
    uint256 constant XP_LEVEL_4 = 1000;
    uint256 constant XP_LEVEL_5 = 2500;
    uint256 constant XP_LEVEL_6 = 5000;
    uint256 constant XP_LEVEL_7 = 10000;
    uint256 constant XP_LEVEL_8 = 25000;
    uint256 constant XP_LEVEL_9 = 50000;
    uint256 constant XP_LEVEL_10 = 100000;

    // Energy caps for each level [Max Energy Caps]
    uint256 constant ENERGY_LEVEL_0 = 10;
    uint256 constant ENERGY_LEVEL_1 = 12;
    uint256 constant ENERGY_LEVEL_2 = 15;
    uint256 constant ENERGY_LEVEL_3 = 20;
    uint256 constant ENERGY_LEVEL_4 = 25;
    uint256 constant ENERGY_LEVEL_5 = 30;
    uint256 constant ENERGY_LEVEL_6 = 35;
    uint256 constant ENERGY_LEVEL_7 = 40;
    uint256 constant ENERGY_LEVEL_8 = 45;
    uint256 constant ENERGY_LEVEL_9 = 50;
    uint256 constant ENERGY_LEVEL_10 = 55;

    // Tier thresholds [Energy Ticks]
    uint256 constant TIER_1_THRESHOLD = 10000 * 1e18;   // 10,000 tokens
    uint256 constant TIER_2_THRESHOLD = 100000 * 1e18;  // 100,000 tokens
    uint256 constant TIER_3_THRESHOLD = 1000000 * 1e18; // 1,000,000 tokens

    // Tick values remain the same [Energy Ticks]
    uint256 constant TIER_0_TICKS = 1;  // 0 tokens
    uint256 constant TIER_1_TICKS = 2;  // 10,000+ tokens
    uint256 constant TIER_2_TICKS = 3;  // 100,000+ tokens
    uint256 constant TIER_3_TICKS = 4;  // 1,000,000+ tokens

    function calculateLevel(uint256 xp) internal pure returns (uint256) {
        if (xp < XP_LEVEL_1) return 0;
        if (xp < XP_LEVEL_2) return 1;
        if (xp < XP_LEVEL_3) return 2;
        if (xp < XP_LEVEL_4) return 3;
        if (xp < XP_LEVEL_5) return 4;
        if (xp < XP_LEVEL_6) return 5;
        if (xp < XP_LEVEL_7) return 6;
        if (xp < XP_LEVEL_8) return 7;
        if (xp < XP_LEVEL_9) return 8;
        if (xp < XP_LEVEL_10) return 9;
        return 10;
    }

    function getMaxEnergy(address player) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        if (!s.addressToPlayer[player].isInitialized) {
            revert PlayerNotInitialized();
        }
        
        uint256 level = s.addressToPlayer[player].level;
        if (level == 0) return ENERGY_LEVEL_0;
        if (level == 1) return ENERGY_LEVEL_1;
        if (level == 2) return ENERGY_LEVEL_2;
        if (level == 3) return ENERGY_LEVEL_3;
        if (level == 4) return ENERGY_LEVEL_4;
        if (level == 5) return ENERGY_LEVEL_5;
        if (level == 6) return ENERGY_LEVEL_6;
        if (level == 7) return ENERGY_LEVEL_7;
        if (level == 8) return ENERGY_LEVEL_8;
        if (level == 9) return ENERGY_LEVEL_9;
        if (level == 10) return ENERGY_LEVEL_10;
        return ENERGY_LEVEL_0; // Default fallback
    }

    function addXP(address player, uint256 amount) internal {
        if (amount == 0) revert InvalidXPAmount();
        
        AppStorage storage s = LibAppStorage.appStorage();
        Player storage p = s.addressToPlayer[player];
        
        if (!p.isInitialized) {
            revert PlayerNotInitialized();
        }

        uint256 newXP = p.xp + amount;
        uint256 newLevel = calculateLevel(newXP);
        
        p.xp = newXP;
        p.level = newLevel;
        
        emit PlayerXPGained(player, amount, newLevel);
    }

    // Add function to update ticks
    function updateRegenTicks(address player) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Player storage p = s.addressToPlayer[player];
        
        if (!p.isInitialized) {
            revert PlayerNotInitialized();
        }

        uint256 tokenBalance = IClankermon(s.clankermon).balanceOf(p.playerAddress);
        
        if (tokenBalance >= TIER_3_THRESHOLD) {
            p.regenTick = TIER_3_TICKS;
        } else if (tokenBalance >= TIER_2_THRESHOLD) {
            p.regenTick = TIER_2_TICKS;
        } else if (tokenBalance >= TIER_1_THRESHOLD) {
            p.regenTick = TIER_1_TICKS;
        } else {
            p.regenTick = TIER_0_TICKS;
        }
    }

    // Add getter for current ticks
    function getCurrentTicks(address player) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        Player storage p = s.addressToPlayer[player];
        
        if (!p.isInitialized) {
            revert PlayerNotInitialized();
        }
        
        return p.regenTick;
    }
}