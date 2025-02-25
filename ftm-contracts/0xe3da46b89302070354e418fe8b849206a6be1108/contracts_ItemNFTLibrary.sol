// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// solhint-disable-next-line no-global-import
import "./contracts_globals_players.sol";

// This file contains methods for interacting with the item NFT, used to decrease implementation deployment bytecode code.
library ItemNFTLibrary {
  function setItem(ItemInput calldata inputItem, Item storage item) external {
    bool hasCombat;
    CombatStats calldata combatStats = inputItem.combatStats;
    assembly ("memory-safe") {
      hasCombat := not(iszero(combatStats))
    }
    item.equipPosition = inputItem.equipPosition;
    item.isTransferable = inputItem.isTransferable;

    bytes1 packedData = bytes1(uint8(0x1)); // Exists
    packedData = packedData | bytes1(uint8(inputItem.isFullModeOnly ? 1 << IS_FULL_MODE_BIT : 0));
    if (inputItem.isAvailable) {
      packedData |= bytes1(uint8(1 << IS_AVAILABLE_BIT));
    }

    item.packedData = packedData;

    item.questPrerequisiteId = inputItem.questPrerequisiteId;

    if (hasCombat) {
      // Combat stats
      item.meleeAttack = inputItem.combatStats.meleeAttack;
      item.rangedAttack = inputItem.combatStats.rangedAttack;
      item.magicAttack = inputItem.combatStats.magicAttack;
      item.meleeDefence = inputItem.combatStats.meleeDefence;
      item.rangedDefence = inputItem.combatStats.rangedDefence;
      item.magicDefence = inputItem.combatStats.magicDefence;
      item.health = inputItem.combatStats.health;
    }

    if (inputItem.healthRestored != 0) {
      item.healthRestored = inputItem.healthRestored;
    }

    if (inputItem.boostType != BoostType.NONE) {
      item.boostType = inputItem.boostType;
      item.boostValue = inputItem.boostValue;
      item.boostDuration = inputItem.boostDuration;
    }

    item.minXP = inputItem.minXP;
    item.skill = inputItem.skill;
  }
}