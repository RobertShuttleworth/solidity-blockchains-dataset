//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IBattlemonItems {
    event MintRandom(
        address indexed account,
        uint256 indexed itemId,
        string itemName
    );

    struct Metadata {
        bool isEquipped;
        uint8 itemType;
        uint8 level;
        // Stats
        uint agility;
        uint speed;
        uint luck;
        // Used only for equipment
        // All the rest of the time = address(0)
        address actualOwner;
        bytes dna;
    }

    function mintRandom(address account) external;
    function rewardMint(address account, uint amount) external;

    // function mintSpecificItem(address account, uint256 itemType, uint256 id, uint256 amount) external;

    function equipItem(uint id, address sender) external;

    function unequipItem(uint id, address sender) external;

    function getItemData(uint tokenId) external view returns (Metadata memory);

    function transferEquippedItem(address to, uint id) external;
}