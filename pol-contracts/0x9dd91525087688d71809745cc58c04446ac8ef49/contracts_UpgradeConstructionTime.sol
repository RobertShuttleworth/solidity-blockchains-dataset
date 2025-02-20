// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_interfaces_IPirateManagement.sol";
import "./contracts_AuthorizationModifiers.sol";

contract UpgradeConstructionTime is AuthorizationModifiers {
    uint256 public constant ONE_DAY = 1 days;

    uint256 public constant DECIMALS = 1e18;
    //uint256 public constant ONE_DAY = 60;
    constructor(
        address _centralAuthorizationRegistry
    ) AuthorizationModifiers(_centralAuthorizationRegistry, keccak256("IUpgradeConstructionTime")) {                
    }

    function getPirateManagement() internal view returns (IPirateManagement) {
        address pirateManagementAddress = centralAuthorizationRegistry.getContractAddress(keccak256("IPirateManagement"));        
        return IPirateManagement(pirateManagementAddress);
    }

    function getOneDayValue() public pure returns (uint256) {
        return ONE_DAY;
    }

    /**
     * @dev Calculate upgrade construction time based on building skill only
     * Formula: (7 * difficulty) / (1 + (building/8))
     * Higher building skill will reduce the construction time
     */
    function calculateUpgradeTime(
        address nftCollection,
        uint256 nftId,
        uint256 difficulty
    ) external view returns (uint256) {
        require(difficulty > 0, "Invalid difficulty");

        IPirateManagement pirateManagement = getPirateManagement();
        IPirateManagement.PirateSkills memory skills = pirateManagement.getPirateSkills(nftCollection, nftId);
        
        // Get building skill (already in wei format)
        uint256 building = skills.specialSkills.building;

        // Base time of 7 days (in seconds) * difficulty
        uint256 baseTime = 7 * ONE_DAY * difficulty;
        
        // If building skill is 0, return base time
        if (building == 0) {
            return baseTime;
        }
        
        // Calculate building modifier: (1 + (building/8))
        // Multiply first to avoid precision loss
        uint256 buildingModifier = DECIMALS + ((building * DECIMALS) / (8 * DECIMALS));
        
        // Calculate total time: baseTime / buildingModifier
        uint256 totalTime = (baseTime * DECIMALS) / buildingModifier;

        return totalTime;
    }
}