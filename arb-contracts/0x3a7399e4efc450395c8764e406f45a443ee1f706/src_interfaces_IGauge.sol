// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

interface IGauge is IERC20 {

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardsAllocated(uint256 reward, uint lockedUntil);
    event Harvest(address indexed user, uint256 reward);

    //╔═══════════════════════════════════════════ GAUGE FUNCTIONS ═══════════════════════════════════════════╗
    function underlying() external view returns (address);
    function yieldSources() external view returns (address[] memory);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function getReward() external returns (uint256);
    function notifyRewardAmount(uint amount) external;

}