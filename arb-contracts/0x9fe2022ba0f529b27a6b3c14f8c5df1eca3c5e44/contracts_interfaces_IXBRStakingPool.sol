// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IXBRStakingPool {
    event Stake(address user, address lp,  uint256 stakeAmount);
    event Unstake(address user, address lp, uint256 unstakeAmount);
    event ClaimReward(address user, uint256 claimedRewardAmount);
    event Exit(address user, address lp, uint256 exitAmount);

    function getLockedTokensByUserAndPool(address user, address pool) external view returns (uint256);
}