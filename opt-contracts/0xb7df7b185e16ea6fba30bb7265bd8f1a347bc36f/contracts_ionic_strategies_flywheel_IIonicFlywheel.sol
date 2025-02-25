// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { ERC20 } from "./solmate_tokens_ERC20.sol";

interface IIonicFlywheel {
  function isRewardsDistributor() external view returns (bool);

  function isFlywheel() external view returns (bool);

  function flywheelPreSupplierAction(address market, address supplier) external;

  function flywheelPreBorrowerAction(address market, address borrower) external;

  function flywheelPreTransferAction(address market, address src, address dst) external;

  function compAccrued(address user) external view returns (uint256);

  function addMarketForRewards(ERC20 strategy) external;

  function marketState(ERC20 strategy) external view returns (uint224 index, uint32 lastUpdatedTimestamp);
}