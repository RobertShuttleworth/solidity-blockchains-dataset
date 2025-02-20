// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {SafeTransferLib, ERC20} from "./solmate_utils_SafeTransferLib.sol";
import {IFlywheelRewards} from "./contracts_ionic_strategies_flywheel_rewards_IFlywheelRewards.sol";
import {IonicFlywheelCore} from "./contracts_ionic_strategies_flywheel_IonicFlywheelCore.sol";

/** 
 @title Flywheel Reward Module
 @notice Determines how many rewards accrue to each strategy globally over a given time period.
 @dev approves the flywheel core for the reward token to allow balances to be managed by the module but claimed from core.
*/
abstract contract BaseFlywheelRewards is IFlywheelRewards {
    using SafeTransferLib for ERC20;

    /// @notice thrown when caller is not the flywheel
    error FlywheelError();

    /// @notice the reward token paid
    ERC20 public immutable override rewardToken;

    /// @notice the flywheel core contract
    IonicFlywheelCore public immutable override flywheel;

    constructor(IonicFlywheelCore _flywheel) {
        flywheel = _flywheel;
        ERC20 _rewardToken = _flywheel.rewardToken();
        rewardToken = _rewardToken;

        _rewardToken.safeApprove(address(_flywheel), type(uint256).max);
    }

    modifier onlyFlywheel() {
        if (msg.sender != address(flywheel)) revert FlywheelError();
        _;
    }
}