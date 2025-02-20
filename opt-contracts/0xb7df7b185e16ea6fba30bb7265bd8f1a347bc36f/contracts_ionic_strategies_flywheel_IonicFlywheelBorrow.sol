// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { ERC20 } from "./solmate_tokens_ERC20.sol";
import { IonicFlywheelCore } from "./contracts_ionic_strategies_flywheel_IonicFlywheelCore.sol";
import "./contracts_ionic_strategies_flywheel_IIonicFlywheel.sol";

contract IonicFlywheelBorrow is IonicFlywheelCore, IIonicFlywheel {
  bool public constant isRewardsDistributor = true;
  bool public constant isFlywheel = true;

  function flywheelPreSupplierAction(address market, address supplier) external {}

  function flywheelPreBorrowerAction(address market, address borrower) external {
    accrue(ERC20(market), borrower);
  }

  function flywheelPreTransferAction(address market, address src, address dst) external {}

  function compAccrued(address user) external view returns (uint256) {
    return _rewardsAccrued[user];
  }

  function addMarketForRewards(ERC20 strategy) external onlyOwner {
    _addStrategyForRewards(strategy);
  }

  // TODO remove
  function marketState(ERC20 strategy) external view returns (uint224, uint32) {
    return (_strategyState[strategy].index, _strategyState[strategy].lastUpdatedTimestamp);
  }
}