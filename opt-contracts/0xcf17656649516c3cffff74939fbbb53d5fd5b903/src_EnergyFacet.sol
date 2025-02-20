// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot} from "./src_AppStorage.sol";
import {AppModifiers} from "./src_AppModifiers.sol";
import {EnergyLibrary} from "./src_libraries_EnergyLibrary.sol";

/**
 * @title EnergyFacet
 * @notice Manages the energy system for Gotchi charging and actions
 * @dev Part of diamond pattern, provides interface for energy management
 *
 * Key features:
 * 1. Time-based energy regeneration (1 point per 15 minutes)
 * 2. Maximum energy cap of 10 points
 * 3. Energy consumption for Gotchi charging
 * 4. Energy initialization for new users
 */
contract EnergyFacet is AppModifiers {
    // Events
    event EnergyInitialized(address indexed account);
    event EnergyUsed(address indexed account, uint256 amount);

    // Custom errors
    error NotInitialized();
    error AlreadyInitialized();
    error InsufficientEnergy();

    /**
     * @notice Initialize energy for a new user
     * @dev Sets initial energy to max and starts regeneration timer
     */
    function initializeEnergy() external {
        EnergyLibrary.initializeEnergy(msg.sender);
    }

    /**
     * @notice Use energy points for an action
     * @param _amount Amount of energy to consume
     * @return Remaining energy balance
     */
    function useEnergy(uint256 _amount) external returns (uint256) {
        return EnergyLibrary.useEnergy(msg.sender, _amount);
    }

    /**
     * @notice Get current energy balance including regeneration
     * @param _account Address to check energy for
     * @return Current energy balance
     */
    function currentEnergy(address _account) external view returns (uint256) {
        return EnergyLibrary.calculateCurrentEnergy(_account);
    }

    /**
     * @notice Get time until next energy point regenerates
     * @param _account Address to check regeneration for
     * @return Seconds until next energy point
     */
    function timeToNextEnergy(address _account) external view returns (uint256) {
        return EnergyLibrary.timeToNextEnergy(_account);
    }

    /**
     * @notice Get maximum possible energy points
     * @return Maximum energy capacity
     */
    function maxEnergy() external pure returns (uint256) {
        return EnergyLibrary.MAX_ENERGY;
    }

    /**
     * @notice Get time between energy regeneration points
     * @return Seconds between each energy point regeneration
     */
    function regenerationPeriod() external pure returns (uint256) {
        return EnergyLibrary.REGEN_PERIOD;
    }
}