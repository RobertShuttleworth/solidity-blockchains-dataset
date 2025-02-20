// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot} from "./src_AppStorage.sol";
import {AppModifiers} from "./src_AppModifiers.sol";
import {EnergyLibrary} from "./src_libraries_EnergyLibrary.sol";
import {PlayerLibrary} from "./src_libraries_PlayerLibrary.sol";

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
     * @notice Get maximum possible energy points for a given address
     * @param _account Address to check max energy for
     * @return Maximum energy capacity based on player level
     */
    function maxEnergy(address _account) external view returns (uint256) {
        return PlayerLibrary.getMaxEnergy(_account);
    }

    /**
     * @notice Get time between energy regeneration points
     * @return Seconds between each energy point regeneration
     */
    function regenerationPeriod() external pure returns (uint256) {
        return EnergyLibrary.REGEN_PERIOD;
    }

    /**
     * @notice Refill energy to max by burning Clankermon tokens
     * @dev Requires REFILL_COST tokens and cooldown to be over
     */
    function refillEnergy() external {
        EnergyLibrary.refillEnergy(msg.sender);
    }

    /**
     * @notice Get time until next refill is available for a given address
     * @param _account Address to check refill cooldown for
     * @return Seconds until next refill available, 0 if available now
     */
    function timeToNextRefill(address _account) external view returns (uint256) {
        return EnergyLibrary.timeToNextRefill(_account);
    }

    /**
     * @notice Get cost of energy refill in Clankermon tokens
     * @return Amount of tokens needed for refill
     */
    function refillCost() external pure returns (uint256) {
        return EnergyLibrary.REFILL_COST;
    }

    /**
     * @notice Get cooldown period between refills
     * @return Seconds between allowed refills
     */
    function refillCooldown() external pure returns (uint256) {
        return EnergyLibrary.REFILL_COOLDOWN;
    }

    /**
     * @notice Set the Clankermon token contract address
     * @dev Only callable by contract owner
     * @param _clankermon Address of the Clankermon ERC20 contract
     */
    function setClankermonToken(address _clankermon) external onlyOwner {
        if (_clankermon == address(0)) revert InvalidAddress();
        s.clankermon = _clankermon;
    }

    error InvalidAddress();
}