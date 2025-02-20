// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICardLevel {
    struct Level {
        uint256 upgradePrice;    // Price to upgrade to this level
        uint256 cashbackRate;    // In basis points (1/10000)
        uint256 rebateRate;      // In basis points (1/10000)
        uint256 requiredReferrals; // Number of referrals needed for free upgrade
    }
    
    function userLevels(uint256 tokenId) external view returns (uint256);
    function levels(uint256 level) external view returns (Level memory);
}