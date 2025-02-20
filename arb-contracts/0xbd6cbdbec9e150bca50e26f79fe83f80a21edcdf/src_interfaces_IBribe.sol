// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBribe {
    function addRewardToken(address rewardToken) external;
    function deposit(uint amount, uint256 lockupId) external;
    function withdraw(uint amount, uint256 lockupId) external;
    function getRewardForOwner(uint tokenId, address[] memory tokens) external;
    function getRewardForAddress(address _owner, address[] memory tokens) external;
    function canNotifyReward() external view returns (bool);
    function notifyRewardAmount(address token, uint amount) external;
    function left(address token) external view returns (uint);
}