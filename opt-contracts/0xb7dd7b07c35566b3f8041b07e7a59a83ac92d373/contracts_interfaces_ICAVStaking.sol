// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICAVStaking {
    function getRewardBalance() external view returns (uint256);

    function addBalance(uint256 amount) external;
}