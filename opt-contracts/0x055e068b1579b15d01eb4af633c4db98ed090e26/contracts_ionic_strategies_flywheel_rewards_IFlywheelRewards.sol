// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ERC20} from "./solmate_tokens_ERC20.sol";
import {IonicFlywheelCore} from "./contracts_ionic_strategies_flywheel_IonicFlywheelCore.sol";

/**
 @title Rewards Module for Flywheel
 @notice Flywheel is a general framework for managing token incentives.
         It takes reward streams to various *strategies* such as staking LP tokens and divides them among *users* of those strategies.

         The Rewards module is responsible for:
         * determining the ongoing reward amounts to entire strategies (core handles the logic for dividing among users)
         * actually holding rewards that are yet to be claimed

         The reward stream can follow arbitrary logic as long as the amount of rewards passed to flywheel core has been sent to this contract.

         Different module strategies include:
         * a static reward rate per second
         * a decaying reward rate
         * a dynamic just-in-time reward stream
         * liquid governance reward delegation (Curve Gauge style)

         SECURITY NOTE: The rewards strategy should be smooth and continuous, to prevent gaming the reward distribution by frontrunning.
 */
interface IFlywheelRewards {
    /**
     @notice calculate the rewards amount accrued to a strategy since the last update.
     @param strategy the strategy to accrue rewards for.
     @param lastUpdatedTimestamp the last time rewards were accrued for the strategy.
     @return rewards the amount of rewards accrued to the market
    */
    function getAccruedRewards(ERC20 strategy, uint32 lastUpdatedTimestamp) external returns (uint256 rewards);

    /// @notice return the flywheel core address
    function flywheel() external view returns (IonicFlywheelCore);

    /// @notice return the reward token associated with flywheel core.
    function rewardToken() external view returns (ERC20);

    function getRewardsPerSecond(ERC20 strategy) external view returns (uint256);
}