// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_interfaces_IPirateManagement.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./contracts_AuthorizationModifiers.sol";


contract ResourceFarmingRules is AuthorizationModifiers {
    using Strings for string;

    constructor(address _centralAuthorizationRegistryContract) AuthorizationModifiers(_centralAuthorizationRegistryContract, keccak256("IResourceFarmingRules")) {}
    
    function calculateResourceOutput(
        IPirateManagement.PirateSkills memory pirate,
        string memory resource,
        uint256 durationSeconds
    ) public pure returns (uint256) {
        uint256 output;
        
        if (resource.equal("coconut")) {
            output = (pirate.characterSkills.agility + pirate.specialSkills.fruitPicking) * durationSeconds/ 1 days;
        } else if (resource.equal("citrus")) {
            output = (pirate.characterSkills.agility + pirate.specialSkills.fruitPicking) * durationSeconds/ 1 days;
        } else if (resource.equal("fish")) {
            output = (((pirate.characterSkills.swimming + pirate.characterSkills.luck)/2) + pirate.specialSkills.fishing) * durationSeconds/ 1 days;
        } else if (resource.equal("tobacco")) {
            output = (((pirate.characterSkills.stamina + pirate.toolsSkills.harvest + pirate.toolsSkills.cultivation + 7 ether)/15) * durationSeconds / 1 days);
        } else if (resource.equal("cotton")) {
            output = (((pirate.characterSkills.stamina * 8) + pirate.toolsSkills.cultivation)/20) * durationSeconds / 1 days;
        } else if (resource.equal("pig")) {
            if (pirate.toolsSkills.husbandry > 0) {
                output = ((((pirate.characterSkills.stamina*2) + pirate.toolsSkills.husbandry) / 30) * durationSeconds / 1 days);
            } else {
                output = (((pirate.characterSkills.stamina*2)/30) * durationSeconds / 1 days);
            }
        } else if (resource.equal("wood")) {            
            if (pirate.toolsSkills.woodcutting > 0) {
                output = (((pirate.characterSkills.melee + pirate.toolsSkills.woodcutting) / 10 ) * durationSeconds / 1 days);
            } else {                
                output = (((pirate.characterSkills.strength + pirate.characterSkills.luck) / 30 ) * durationSeconds / 1 days);
            }
        } else if (resource.equal("sugarcane")) {
            require(pirate.toolsSkills.harvest > 0, "Pirate does not have harvesting tool");
            output = (((((pirate.characterSkills.stamina/1e18 * pirate.toolsSkills.harvest/1e18)*10**18) + pirate.toolsSkills.cultivation)/30) * durationSeconds / 1 days);
        } else if (resource.equal("grain")) {
            require(pirate.toolsSkills.harvest > 0, "Pirate does not have harvesting tool");
            output = (((((pirate.characterSkills.stamina/1e18 * pirate.toolsSkills.harvest/1e18)*10**18) + pirate.toolsSkills.cultivation)/20) * durationSeconds / 1 days);
        } else if (resource.equal("planks")) {
            require(pirate.toolsSkills.woodcutting >= 4 ether, "Pirate does not have woodcutting tool");
            output = (((pirate.characterSkills.agility + pirate.characterSkills.strength) /10) * durationSeconds / 1 days);
        } else if (resource.equal("meat")) {
            require(pirate.toolsSkills.slaughter > 0, "Pirate does not have slaughtering tool");
            output = ((pirate.characterSkills.melee + pirate.toolsSkills.slaughter) / 10) * durationSeconds / 1 days;
        } else if (resource.equal("barrel-packed fish")) {
            output = (pirate.characterSkills.agility + pirate.characterSkills.stamina) * durationSeconds / 1 days;
        } else if (resource.equal("barrel-packed meat")) {
            output = (pirate.characterSkills.agility + pirate.characterSkills.stamina) * durationSeconds / 1 days;
        } else if (resource.equal("crates")) {
            require(pirate.specialSkills.crafting > 0 || pirate.toolsSkills.woodcutting > 3 ether, "Pirate does not have crafting or woodcutting tool");
            if (pirate.specialSkills.crafting > 0) {
                output = (pirate.characterSkills.agility) * durationSeconds / 1 days;
            } else {
                output = (pirate.characterSkills.agility / 3) * durationSeconds / 1 days;
            }
        } else if (resource.equal("barrels")) {
            require(pirate.toolsSkills.woodcutting > 3 ether || pirate.specialSkills.crafting > 0, "Pirate does not have woodcutting or crafting tool");
            if (pirate.specialSkills.crafting > 0) {
                output = ((pirate.characterSkills.agility + pirate.characterSkills.wisdom) / 5) * durationSeconds / 1 days;
            } else if (pirate.toolsSkills.woodcutting > 3 ether) {
               output = ((pirate.characterSkills.agility + pirate.characterSkills.wisdom) / 20) * durationSeconds / 1 days;
            }
        } else if (resource.equal("bags")) {            
            output = (pirate.characterSkills.agility) * durationSeconds / 1 days;
        } else if (resource.equal("bag-packed tobacco")) {
            if (pirate.toolsSkills.slaughter == 3 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 2) * durationSeconds / 1 days;
            } else {
                output = (pirate.characterSkills.strength + pirate.characterSkills.stamina) * durationSeconds / 1 days;
            }
        } else if (resource.equal("bag-packed grain")) {
            if (pirate.toolsSkills.husbandry == 8 ether && pirate.toolsSkills.excavation == 8 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 3) * durationSeconds / 1 days;
            } else if (pirate.toolsSkills.husbandry == 8 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 2) * durationSeconds / 1 days;
            } else if (pirate.toolsSkills.excavation == 8 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 2) * durationSeconds / 1 days;
            } else {
                output = (pirate.characterSkills.strength + pirate.characterSkills.stamina) * durationSeconds / 1 days;
            }
        } else if (resource.equal("bag-packed cotton")) {
            if (pirate.toolsSkills.slaughter == 3 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 2) * durationSeconds / 1 days;
            } else {
                output = (pirate.characterSkills.strength + pirate.characterSkills.stamina) * durationSeconds / 1 days;
            }
        } else if (resource.equal("bag-packed sugarcane")) {
            if (pirate.toolsSkills.husbandry == 8 ether && pirate.toolsSkills.harvest == 3 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 3) * durationSeconds / 1 days;
            } else if (pirate.toolsSkills.husbandry == 8 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 2) * durationSeconds / 1 days;
            } else if (pirate.toolsSkills.harvest == 3 ether) {
                output = ((pirate.characterSkills.strength + pirate.characterSkills.stamina) * 2) * durationSeconds / 1 days;
            } else {
                output = (pirate.characterSkills.strength + pirate.characterSkills.stamina) * durationSeconds / 1 days;
            }
        } else if (resource.equal("wild game")) {
            require(pirate.toolsSkills.hunting > 0, "Pirate does not have hunting tool");
            output = ((pirate.toolsSkills.hunting + pirate.characterSkills.luck + pirate.characterSkills.shooting) / 10) * durationSeconds / 1 days;
        } else if (resource.equal("coconut liquor")) {
            output = ((pirate.characterSkills.agility + pirate.characterSkills.wisdom) / 3) * durationSeconds / 1 days;
        } else if (resource.equal("crate-packed citrus")) {
            output = ((pirate.characterSkills.agility + pirate.characterSkills.stamina)*2) * durationSeconds / 1 days;
        } else if (resource.equal("crate-packed coconuts")) {
            output = ((pirate.characterSkills.agility + pirate.characterSkills.stamina)*2) * durationSeconds / 1 days;
        } else {
            revert("Invalid resource type");
        }

        return output;
    }
}