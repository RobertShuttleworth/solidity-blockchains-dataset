// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ERC20} from "./solmate_tokens_ERC20.sol";

import { ICErc20 } from "./contracts_compound_CTokenInterfaces.sol";
import "./contracts_ionic_strategies_flywheel_IFlywheelBooster.sol";

contract IonicFlywheelSupplyBooster is IFlywheelBooster {
  string public constant BOOSTER_TYPE = "IonicFlywheelSupplyBooster";

  /**
      @notice calculate the boosted supply of a strategy.
      @param strategy the strategy to calculate boosted supply of
      @return the boosted supply
     */
  function boostedTotalSupply(ERC20 strategy) external view returns (uint256) {
    ICErc20 asMarket = ICErc20(address(strategy));
    return asMarket.getTotalUnderlyingSupplied();
  }

  /**
      @notice calculate the boosted balance of a user in a given strategy.
      @param strategy the strategy to calculate boosted balance of
      @param user the user to calculate boosted balance of
      @return the boosted balance
     */
  function boostedBalanceOf(ERC20 strategy, address user) external view returns (uint256) {
    ICErc20 asMarket = ICErc20(address(strategy));
    return asMarket.balanceOfUnderlying(user);
  }
}