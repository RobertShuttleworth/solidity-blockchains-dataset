// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Auth, Authority} from "./solmate_auth_Auth.sol";
import {BaseFlywheelRewards} from "./contracts_ionic_strategies_flywheel_rewards_BaseFlywheelRewards.sol";
import {ERC20} from "./solmate_utils_SafeTransferLib.sol";
import {IonicFlywheelCore} from "./contracts_ionic_strategies_flywheel_IonicFlywheelCore.sol";
import { SafeTransferLib, ERC20 } from "./solmate_utils_SafeTransferLib.sol";
import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";

/** 
 @title Ionic Flywheel Static Reward Stream
 @notice Determines rewards per strategy based on a fixed reward rate per second
*/
contract IonicFlywheelStaticRewards is Ownable, BaseFlywheelRewards {
    using SafeTransferLib for ERC20;

    event RewardsInfoUpdate(ERC20 indexed strategy, uint224 rewardsPerSecond, uint32 rewardsEndTimestamp);

    struct RewardsInfo {
        /// @notice Rewards per second
        uint224 rewardsPerSecond;
        /// @notice The timestamp the rewards end at
        /// @dev use 0 to specify no end
        uint32 rewardsEndTimestamp;
    }

    /// @notice rewards info per strategy
    mapping(ERC20 => RewardsInfo) public rewardsInfo;

    constructor(IonicFlywheelCore _flywheel) Ownable() BaseFlywheelRewards(_flywheel) {}

    /**
     @notice set rewards per second and rewards end time for Fei Rewards
     @param strategy the strategy to accrue rewards for
     @param rewards the rewards info for the strategy
     */
    function setRewardsInfo(ERC20 strategy, RewardsInfo calldata rewards) external onlyOwner {
        rewardsInfo[strategy] = rewards;
        emit RewardsInfoUpdate(strategy, rewards.rewardsPerSecond, rewards.rewardsEndTimestamp);
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param strategy the strategy to accrue rewards for
     @param lastUpdatedTimestamp the last updated time for strategy
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 strategy, uint32 lastUpdatedTimestamp)
        external
        view
        override
        onlyFlywheel
        returns (uint256 amount)
    {
        RewardsInfo memory rewards = rewardsInfo[strategy];

        uint256 elapsed;
        if (rewards.rewardsEndTimestamp == 0 || rewards.rewardsEndTimestamp > block.timestamp) {
            elapsed = block.timestamp - lastUpdatedTimestamp;
        } else if (rewards.rewardsEndTimestamp > lastUpdatedTimestamp) {
            elapsed = rewards.rewardsEndTimestamp - lastUpdatedTimestamp;
        }

        amount = rewards.rewardsPerSecond * elapsed;
    }

    function getRewardsPerSecond(ERC20 strategy) external view override returns (uint256) {
        RewardsInfo memory rewards = rewardsInfo[strategy];

        if (rewards.rewardsEndTimestamp == 0 || rewards.rewardsEndTimestamp > block.timestamp) {
            return rewards.rewardsPerSecond;
        } else {
            return 0;
        }
    }

    function withdraw(uint256 amount) external onlyOwner {
        rewardToken.safeTransfer(msg.sender, amount);
    }
}