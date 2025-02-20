// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot, Gotchi} from "./src_AppStorage.sol";
import {AppModifiers} from "./src_AppModifiers.sol";
import {console} from "./lib_forge-std_src_Test.sol";
import {GotchiLibrary} from "./src_libraries_GotchiLibrary.sol";
import {IERC721} from "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import {EnergyLibrary} from "./src_libraries_EnergyLibrary.sol";

/**
 * @title GotchiFacet
 * @notice Manages Gotchi lifecycle including charging, death, revival and burial
 * @dev Part of diamond pattern, inherits AppModifiers for access control
 *
 * Key features:
 * 1. Energy-based charging system that grants XP
 * 2. Death after 48 hours without charging
 * 3. Revival window of 48 hours after death
 * 4. Permanent burial (burning) after revival window
 */
contract GotchiFacet is AppModifiers {
    // Events for tracking Gotchi lifecycle changes
    event GotchiCharged(uint256 tokenId, uint256 energy);
    event GotchiDied(uint256 tokenId);
    event GotchiRevived(uint256 tokenId);
    event GotchiBuried(uint256 tokenId);

    // Custom errors for better gas efficiency and clarity
    error GotchiNotDead();
    error GotchiPastRevivalWindow();
    error NotEnoughEnergy();

    /**
     * @notice Charges a Gotchi with energy to keep it alive and gain XP
     * @dev Only callable by Gotchi owner and if Gotchi is alive
     * @param _tokenId The ID of the Gotchi to charge
     * @param _energy Amount of energy to use for charging
     * @custom:events Emits GotchiCharged
     */
    function charge(uint256 _tokenId, uint256 _energy) 
        external 
        onlyGotchiOwner(_tokenId)
        onlyNonDeadGotchis(_tokenId) 
    {
        // Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        // Use EnergyLibrary's useEnergy function which handles regeneration
        EnergyLibrary.useEnergy(msg.sender, _energy);
        
        GotchiLibrary.updateGotchiStatus(_tokenId);
        GotchiLibrary.chargeGotchi(_tokenId, _energy);
        
        emit GotchiCharged(_tokenId, _energy);
    }

    /**
     * @notice Revives a dead Gotchi within the revival window
     * @dev Only callable by Gotchi owner and within 48 hours of death
     * @param _tokenId The ID of the Gotchi to revive
     * @custom:events Emits GotchiRevived
     */
    function revive(uint256 _tokenId) 
        external 
        onlyGotchiOwner(_tokenId) 
    {
        Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        if (!gotchi.isDead) {
            revert GotchiNotDead();
        }
        
        if (block.timestamp > gotchi.deathTime + GotchiLibrary.REVIVAL_WINDOW) {
            revert GotchiPastRevivalWindow();
        }
        
        GotchiLibrary.reviveGotchi(_tokenId);
        emit GotchiRevived(_tokenId);
    }

    /**
     * @notice Permanently burns (buries) a dead Gotchi after revival window
     * @dev Only callable by Gotchi owner after revival window has passed
     * @param _tokenId The ID of the Gotchi to bury
     * @custom:events Emits GotchiBuried
     */
    function bury(uint256 _tokenId) 
        external 
        onlyGotchiOwner(_tokenId) 
    {
        Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        if (!gotchi.isDead) {
            revert GotchiNotDead();
        }
        
        if (block.timestamp <= gotchi.deathTime + GotchiLibrary.REVIVAL_WINDOW) {
            revert GotchiNotDead();
        }

        // Handle NFT burning through diamond pattern
        bytes4 selector = bytes4(keccak256("burn(uint256)"));
        (bool success,) = address(this).delegatecall(
            abi.encodeWithSelector(selector, _tokenId)
        );
        require(success, "Burn failed");

        emit GotchiBuried(_tokenId);
    }

    //// GETTERS ////

    /**
     * @notice Retrieves full Gotchi data
     * @param _tokenId The ID of the Gotchi
     * @return Gotchi struct containing all Gotchi data
     */
    function getGotchi(uint256 _tokenId) external view returns (Gotchi memory) {
        return s.tokenIdToGotchi[_tokenId];
    }

    /**
     * @notice Retrieves multiple Gotchis' data in a single call
     * @param _tokenIds Array of Gotchi token IDs
     * @return Array of Gotchi structs containing all Gotchi data
     */
    function getGotchis(uint256[] calldata _tokenIds) external view returns (Gotchi[] memory) {
        Gotchi[] memory gotchis = new Gotchi[](_tokenIds.length);
        
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // Verify the token exists by checking if it has an owner
            require(IERC721(address(this)).ownerOf(_tokenIds[i]) != address(0), "Token does not exist");
            gotchis[i] = s.tokenIdToGotchi[_tokenIds[i]];
        }
        
        return gotchis;
    }

    /**
     * @notice Retrieves all Gotchis owned by an address
     * @param _owner Address to query Gotchis for
     * @return Array of Gotchi structs for all owned Gotchis
     */
    function getGotchisByOwner(address _owner) external view returns (Gotchi[] memory) {
        uint256[] memory tokenIds = GotchiLibrary.getTokenIdsForOwner(_owner);
        Gotchi[] memory gotchis = new Gotchi[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            gotchis[i] = s.tokenIdToGotchi[tokenIds[i]];
        }
        
        return gotchis;
    }

    /**
     * @notice Gets remaining time before Gotchi dies
     * @param _tokenId The ID of the Gotchi
     * @return Remaining time in seconds before death (0 if already dead)
     */
    function timeToLive(uint256 _tokenId) external view returns (uint256) {
        return GotchiLibrary.getTimeToLive(_tokenId);
    }

    /**
     * @notice Checks if a Gotchi is dead
     * @param _tokenId The ID of the Gotchi
     * @return bool True if Gotchi is dead
     */
    function isDead(uint256 _tokenId) external view returns (bool) {
        return s.tokenIdToGotchi[_tokenId].isDead;
    }

    /**
     * @notice Gets the current level of a Gotchi
     * @param _tokenId The ID of the Gotchi
     * @return uint256 Current level based on XP
     */
    function getLevel(uint256 _tokenId) external view returns (uint256) {
        return s.tokenIdToGotchi[_tokenId].level;
    }

    /**
     * @notice Gets the total XP of a Gotchi
     * @param _tokenId The ID of the Gotchi
     * @return uint256 Total accumulated XP
     */
    function getXP(uint256 _tokenId) external view returns (uint256) {
        return s.tokenIdToGotchi[_tokenId].xp;
    }
}