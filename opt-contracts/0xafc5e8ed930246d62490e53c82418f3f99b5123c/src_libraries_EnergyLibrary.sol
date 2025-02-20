// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {AppStorage} from "./src_AppStorage.sol";
import {console} from "./lib_forge-std_src_Test.sol";
import {PlayerLibrary} from "./src_libraries_PlayerLibrary.sol";

// Move interface outside the library
interface IClankermon {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title EnergyLibrary
 * @notice Core logic for energy system management
 * @dev Implements regenerative energy system with max cap and time-based regeneration
 *
 * Functions:
 * - initializeEnergy(address): Set up initial energy for an address
 * - useEnergy(address, uint256): Consume energy points
 * - updateEnergy(address): Update energy based on time elapsed
 * - calculateCurrentEnergy(address): Calculate current energy including regeneration
 * - timeToNextEnergy(address): Get time until next energy point regenerates
 * - refillEnergy(address): Refill energy to max using Clankermon tokens
 * - timeToNextRefill(address): Get time until next refill is available
 *
 * Constants:
 * - REGEN_PERIOD: 15 minutes
 * - REFILL_COOLDOWN: 12 hours
 * - REFILL_COST: 100 Clankermon tokens
 */
library EnergyLibrary {
    // Core constants
    uint256 public constant REGEN_PERIOD = 15 minutes;
    uint256 public constant REFILL_COOLDOWN = 12 hours;
    uint256 public constant REFILL_COST = 1000 * 1e18;  // 100 Clankermon tokens
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;  // Add burn address

    // Events
    event EnergyInitialized(address indexed account);
    event EnergyUsed(address indexed account, uint256 amount);
    event EnergyRefilled(address indexed account, uint256 amount);

    // Custom errors
    error Energy_NotInitialized();
    error Energy_AlreadyInitialized();
    error Energy_InsufficientEnergy();
    error Energy_RefillCooldownActive();
    error Energy_InsufficientClankermon();

    /**
     * @notice Initialize energy for a new account
     * @dev Sets initial energy to MAX_ENERGY and records timestamp
     */
    function initializeEnergy(address _account) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.addressToPlayer[_account].isInitialized == false) {
            revert("Player not initialized");
        }
        
        uint256 maxEnergy = PlayerLibrary.getMaxEnergy(_account);
        s.addressToEnergy[_account] = maxEnergy;
        s.lastEnergyUpdate[_account] = block.timestamp;
        
        emit EnergyInitialized(_account);
    }

    /**
     * @notice Use energy points for an action
     * @dev Updates energy before consumption and checks for sufficient balance
     */
    function useEnergy(address _user, uint256 _amount) internal returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.lastEnergyUpdate[_user] == 0) {
            revert Energy_NotInitialized();
        }
        
        uint256 current = calculateCurrentEnergy(_user);
        if (_amount > current) {
            revert Energy_InsufficientEnergy();
        }
        
        // Calculate the partial progress towards next regeneration
        uint256 timeSinceUpdate = block.timestamp - s.lastEnergyUpdate[_user];
        uint256 partialProgress = timeSinceUpdate % REGEN_PERIOD;
        
        // Update energy and maintain the partial progress
        s.addressToEnergy[_user] = current - _amount;
        s.lastEnergyUpdate[_user] = block.timestamp - partialProgress;
        
        emit EnergyUsed(_user, _amount);
        return current - _amount;
    }

    /**
     * @notice Update energy based on time elapsed since last update
     * @dev Calculates regenerated energy and updates storage
     */
    function updateEnergy(address _account) internal returns (uint256) {
        uint256 newEnergy = calculateCurrentEnergy(_account);
        AppStorage storage s = LibAppStorage.appStorage();
        s.addressToEnergy[_account] = newEnergy;
        s.lastEnergyUpdate[_account] = block.timestamp;
        return newEnergy;
    }

    /**
     * @notice Calculate current energy including regeneration
     * @dev Accounts for time-based regeneration up to MAX_ENERGY
     */
    function calculateCurrentEnergy(address _account) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 maxEnergy = PlayerLibrary.getMaxEnergy(_account);
        uint256 lastUpdate = s.lastEnergyUpdate[_account];
        if (lastUpdate == 0) {
            revert Energy_NotInitialized();
        }

        uint256 currentBalance = s.addressToEnergy[_account];
        uint256 elapsedTime = block.timestamp - lastUpdate;
        uint256 regenTicks = PlayerLibrary.getCurrentTicks(_account);
        uint256 regeneratedEnergy = (elapsedTime / REGEN_PERIOD) * regenTicks;

        uint256 newBalance = currentBalance + regeneratedEnergy;
        return newBalance > maxEnergy ? maxEnergy : newBalance;
    }

    /**
     * @notice Calculate time until next energy point regenerates
     * @dev Returns 0 if at max energy
     */
    function timeToNextEnergy(address _account) internal view returns (uint256) {
        uint256 current = calculateCurrentEnergy(_account);
        if (current >= PlayerLibrary.getMaxEnergy(_account)) return 0;
        
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 lastUpdate = s.lastEnergyUpdate[_account];
        uint256 timeSinceUpdate = block.timestamp - lastUpdate;
        uint256 nextRegenTime = ((timeSinceUpdate / REGEN_PERIOD) + 1) * REGEN_PERIOD;
        
        return nextRegenTime - timeSinceUpdate;
    }

    /**
     * @notice Refill energy to max using Clankermon tokens
     * @dev Burns REFILL_COST tokens and sets energy to max
     */
    function refillEnergy(address _account) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        
        // Check cooldown
        if (block.timestamp < s.lastEnergyRefill[_account] + REFILL_COOLDOWN) {
            revert Energy_RefillCooldownActive();
        }

        // Check Clankermon balance
        uint256 clankermonBalance = IClankermon(s.clankermon).balanceOf(_account);
        if (clankermonBalance < REFILL_COST) {
            revert Energy_InsufficientClankermon();
        }

        // Transfer Clankermon tokens from user to burn address
        IClankermon(s.clankermon).transferFrom(_account, BURN_ADDRESS, REFILL_COST);

        // Set energy to max
        uint256 maxEnergy = PlayerLibrary.getMaxEnergy(_account);
        s.addressToEnergy[_account] = maxEnergy;
        s.lastEnergyUpdate[_account] = block.timestamp;
        s.lastEnergyRefill[_account] = block.timestamp;

        emit EnergyRefilled(_account, maxEnergy);
    }

    /**
     * @notice Get time until next refill is available
     * @return Time in seconds until next refill, 0 if available now
     */
    function timeToNextRefill(address _account) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 lastRefill = s.lastEnergyRefill[_account];
        
        if (block.timestamp >= lastRefill + REFILL_COOLDOWN) {
            return 0;
        }
        
        return (lastRefill + REFILL_COOLDOWN) - block.timestamp;
    }
}