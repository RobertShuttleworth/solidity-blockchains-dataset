// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IUpgradeConstructionTime {
    /**
     * @dev Calculate upgrade construction time based on pirate skills and difficulty
     * @param nftCollection The address of the NFT collection
     * @param nftId The ID of the NFT
     * @param difficulty The difficulty level of the upgrade
     * @return The calculated upgrade time in seconds
     */
    function calculateUpgradeTime(
        address nftCollection,
        uint256 nftId,
        uint256 difficulty
    ) external view returns (uint256);

    /**
     * @dev Get the value of one day in seconds
     * @return The number of seconds in one day
     */
    function getOneDayValue() external pure returns (uint256);

    /**
     * @dev The number of seconds in one day
     */
    function ONE_DAY() external view returns (uint256);
}