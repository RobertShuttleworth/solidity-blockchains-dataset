// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {AppStorage} from "./src_AppStorage.sol";
import {console} from "./lib_forge-std_src_Test.sol";

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
 *
 * Constants:
 * - MAX_ENERGY: 10 points
 * - REGEN_PERIOD: 15 minutes
 */
library EnergyLibrary {
    // Core constants
    uint256 public constant MAX_ENERGY = 10;
    uint256 public constant REGEN_PERIOD = 15 minutes;

    // Events
    event EnergyInitialized(address indexed account);
    event EnergyUsed(address indexed account, uint256 amount);

    // Custom errors
    error Energy_NotInitialized();
    error Energy_AlreadyInitialized();
    error Energy_InsufficientEnergy();

    /**
     * @notice Initialize energy for a new account
     * @dev Sets initial energy to MAX_ENERGY and records timestamp
     */
    function initializeEnergy(address _account) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.lastEnergyUpdate[_account] != 0) {
            revert Energy_AlreadyInitialized();
        }
        
        s.lastEnergyUpdate[_account] = block.timestamp;
        s.addressToEnergy[_account] = MAX_ENERGY;
        
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
        
        uint256 current = updateEnergy(_user);
        if (_amount > current) {
            revert Energy_InsufficientEnergy();
        }
        
        s.addressToEnergy[_user] = current - _amount;
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
        uint256 lastUpdate = s.lastEnergyUpdate[_account];
        if (lastUpdate == 0) {
            revert Energy_NotInitialized();
        }

        uint256 currentBalance = s.addressToEnergy[_account];
        uint256 elapsedTime = block.timestamp - lastUpdate;
        uint256 regeneratedEnergy = (elapsedTime / REGEN_PERIOD);

        uint256 newBalance = currentBalance + regeneratedEnergy;
        return newBalance > MAX_ENERGY ? MAX_ENERGY : newBalance;
    }

    /**
     * @notice Calculate time until next energy point regenerates
     * @dev Returns 0 if at max energy
     */
    function timeToNextEnergy(address _account) internal view returns (uint256) {
        uint256 current = calculateCurrentEnergy(_account);
        if (current >= MAX_ENERGY) return 0;
        
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 lastUpdate = s.lastEnergyUpdate[_account];
        uint256 timeSinceUpdate = block.timestamp - lastUpdate;
        uint256 nextRegenTime = ((timeSinceUpdate / REGEN_PERIOD) + 1) * REGEN_PERIOD;
        
        return nextRegenTime - timeSinceUpdate;
    }
}