// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IReferralStorage {
    struct ReferralInfo {
        uint256 referrerTokenId;
        uint256 timestamp;
        uint256 paymentAmount;
    }

    event ReferralSet(uint256 indexed userTokenId, uint256 indexed referrerTokenId, uint256 paymentAmount);

    function setReferrer(uint256 userTokenId, uint256 referrerTokenId, uint256 paymentAmount) external;
    function referrals(uint256 userTokenId) external view returns (ReferralInfo memory);
    function referralCounts(uint256 referrerTokenId) external view returns (uint256);
    function getUsersByReferrer(
        uint256 referrerTokenId,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory users, uint256 total);
} 