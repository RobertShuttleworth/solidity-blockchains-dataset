// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IFeeManagement {
    function rumToken() external view returns (address);
    function rumFeePerDay() external view returns (uint256);
    function maticFeePerDay() external view returns (uint256);
    function maticFeeRecipient() external view returns (address);

    function useRum(address user, uint256 days_count) external;
    function calculateRumFee(uint256 days_count) external view returns (uint256);
    function calculateMaticFee(uint256 days_count) external view returns (uint256);
    function setRumFeePerDay(uint256 newFee) external;
    function setMaticFeePerDay(uint256 newFee) external;
    function setMaticFeeRecipient(address newRecipient) external;

    event RumUsed(address indexed user, uint256 amount);
    event MaticUsed(address indexed user, uint256 amount);
    event RumFeePerDayUpdated(uint256 newFee);
    event MaticFeePerDayUpdated(uint256 newFee);
    event MaticFeeRecipientUpdated(address newRecipient);
}