// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IReferralConfig {
    function getReferralInfo(uint160 id) external view returns (uint256 tradeDiscount, uint256 rebate, address referrer);
    function getTraderReferralCode(address account) external view returns (uint160);
    function setTraderReferralCode(address account, uint160 id) external;
}