// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

/// @title IPearBase
/// @notice Base logic for all Pear contracts.
interface IPearStaker is IERC20 {
    function initialize(address _pearToken, address _comptroller) external;
    function stake(uint256 amount) external;
    function stakeFor(address account, uint256 amount) external;
    function unstake(uint256 amount) external;
    function depositStakerFee() external payable;
    function earned(address account) external view returns (uint256, uint256);
    function getReward() external;
    function getStakingReward() external;
    function compoundStakingReward() external;
    function getExitFeeReward() external;

    function setUniswapData(address _uniswapRouter, uint24 _poolFee) external;
}