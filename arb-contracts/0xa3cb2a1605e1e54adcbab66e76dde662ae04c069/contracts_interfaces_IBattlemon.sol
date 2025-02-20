//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./contracts_interfaces_IBattlemonItems.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_IERC721Upgradeable.sol";

interface IBattlemon is IERC721Upgradeable {
    event EquipmentChanged(
        address indexed owner,
        uint256 indexed lemonId,
        Metadata lemonData,
        int[] itemsIds,
        IBattlemonItems.Metadata[10] itemsMetadata
    );
    event Lvlup(
        uint256 indexed tokenId,
        uint256 lemonType,
        uint256 indexed level,
        uint256 agility,
        uint256 speed,
        uint256 luck,
        bytes dna
    );
    event Create(
        address indexed to,
        uint256 indexed tokenId,
        uint8 indexed lemonType,
        uint256 agility,
        uint256 speed,
        uint256 luck,
        bytes dna,
        uint256 level
    );
    event CrosschainTransfer(
        address indexed to,
        uint256 indexed tokenId,
        uint8 indexed lemonType,
        uint256 agility,
        uint256 speed,
        uint256 luck,
        bytes dna,
        uint256 level
    );

    struct Metadata {
        uint8 level;
        // 0-OMEGA, 1-ALPHA
        uint8 lemonType;
        bytes dna;
        uint256 agility;
        uint256 speed;
        uint256 luck;
    }

    struct EquippedItem {
        uint256 itemId;
        // Required because itemId can be 0 when item actually has id == 0
        bool equipped;
    }

    function sendLemonToRaid(uint256 lemonId, address caller) external;

    function boxMint(address to) external;

    function levelOf(uint id) external view returns (uint8);

    function lemonData(uint id) external view returns (Metadata memory);
}