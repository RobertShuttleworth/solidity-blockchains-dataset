// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {AppStorage, Gotchi} from "./src_AppStorage.sol";
import {console} from "./lib_forge-std_src_Test.sol";

/**
 * @title GotchiLibrary
 * @notice Core logic for Gotchi lifecycle management and NFT operations
 * @dev Implements energy-based charging system, death mechanics, and NFT operations
 *
 * Functions:
 * - initGotchi(uint256): Initialize new Gotchi with default values
 * - transferGotchi(address, address, uint256): Handle NFT transfer logic
 * - isApprovedOrOwner(address, uint256): Check if address can manage Gotchi
 * - updateGotchiStatus(uint256): Update Gotchi's life/death status
 * - chargeGotchi(uint256, uint256): Charge Gotchi with energy and gain XP
 * - reviveGotchi(uint256): Revive a dead Gotchi
 * - getTimeToLive(uint256): Get remaining time before Gotchi dies
 * - calculateLevel(uint256): Calculate Gotchi level from XP
 *
 * Constants:
 * - TIME_TO_LIVE: 48 hours
 * - REVIVAL_WINDOW: 48 hours
 * - XP_PER_CHARGE: 10
 */
 
library GotchiLibrary {
    // Core timing constants
    uint256 public constant TIME_TO_LIVE = 48 hours;
    uint256 public constant REVIVAL_WINDOW = 48 hours;
    uint256 public constant XP_PER_CHARGE = 10;

    // Events
    event GotchiTransferred(uint256 indexed tokenId, address from, address to);
    event GotchiApproved(uint256 indexed tokenId, address approved);
    event GotchiOperatorApproval(address indexed owner, address indexed operator, bool approved);

    /**
     * @notice Initializes a new Gotchi with default values
     * @dev Called when minting a new Gotchi
     */
    function initGotchi(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.tokenIdToGotchi[_tokenId] = Gotchi(
            _tokenId,
            msg.sender,
            block.timestamp,
            0,
            0,
            0,
            false
        );
    }

        /**
     * @notice Gets all token IDs owned by an address
     * @dev Helper function for facets needing to query ownership
     * @param owner Address to query tokens for
     * @return Array of token IDs owned by the address
     */
    function getTokenIdsForOwner(address owner) internal view returns (uint256[] memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        require(owner != address(0), "Zero address");
        
        // First count owned tokens
        uint256 tokenCount = 0;
        for (uint256 i = 0; i < s.nextTokenId; i++) {
            if (s.tokenIdToGotchi[i].owner == owner) {
                tokenCount++;
            }
        }
        
        // Then create and fill array
        uint256[] memory tokens = new uint256[](tokenCount);
        uint256 index = 0;
        for (uint256 i = 0; i < s.nextTokenId; i++) {
            if (s.tokenIdToGotchi[i].owner == owner) {
                tokens[index] = i;
                index++;
            }
        }
        
        return tokens;
    }

    /**
     * @notice Handles NFT transfer logic including approval clearing
     * @dev Checks for dead Gotchi and proper ownership/approval
     */
    function transferGotchi(address _from, address _to, uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        require(_to != address(0), "Zero address transfer");
        require(!gotchi.isDead, "Dead Gotchi not transferable");
        
        // Clear approvals
        delete s.tokenApprovals[_tokenId];
        
        // Update ownership
        gotchi.owner = _to;
        
        emit GotchiTransferred(_tokenId, _from, _to);
    }

    /**
     * @notice Checks if an address is approved to manage a Gotchi
     * @dev Combines owner and approval checks
     */
    function isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        address owner = s.tokenIdToGotchi[_tokenId].owner;
        
        return (_spender == owner ||
                s.tokenApprovals[_tokenId] == _spender ||
                s.operatorApprovals[owner][_spender]);
    }

    /**
     * @notice Updates Gotchi's life status based on last charge time
     * @dev Checks if Gotchi should be marked as dead
     */
    function updateGotchiStatus(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        if (!gotchi.isDead && 
            block.timestamp > gotchi.lastChargeTime + TIME_TO_LIVE) {
            gotchi.isDead = true;
            gotchi.deathTime = block.timestamp;
        }
    }

    /**
     * @notice Charges a Gotchi with energy and updates XP
     * @dev Updates last charge time and calculates XP gain
     */
    function chargeGotchi(uint256 _tokenId, uint256 _energy) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        gotchi.lastChargeTime = block.timestamp;
        gotchi.xp += _energy * XP_PER_CHARGE;
        gotchi.level = calculateLevel(gotchi.xp);
    }

    /**
     * @notice Revives a dead Gotchi
     * @dev Resets death status and updates last charge time
     */
    function reviveGotchi(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        gotchi.isDead = false;
        gotchi.deathTime = 0;
        gotchi.lastChargeTime = block.timestamp;
    }

    /**
     * @notice Calculates remaining time before Gotchi dies
     * @dev Returns 0 if already dead or past TIME_TO_LIVE
     */
    function getTimeToLive(uint256 _tokenId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        Gotchi storage gotchi = s.tokenIdToGotchi[_tokenId];
        
        if (gotchi.isDead) return 0;
        
        uint256 timeSinceCharge = block.timestamp - gotchi.lastChargeTime;
        if (timeSinceCharge >= TIME_TO_LIVE) return 0;
        
        return TIME_TO_LIVE - timeSinceCharge;
    }

    /**
     * @notice Calculates Gotchi level based on XP
     * @dev Simple calculation: 1 level per 100 XP
     * //P1 - Add real level calculation
     */
    function calculateLevel(uint256 _xp) internal pure returns (uint256) {
        return _xp / 100;
    }
}