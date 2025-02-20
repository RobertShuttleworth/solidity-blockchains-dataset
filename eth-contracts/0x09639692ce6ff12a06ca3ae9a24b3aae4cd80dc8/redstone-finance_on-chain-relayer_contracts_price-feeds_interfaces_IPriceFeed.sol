// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";
import {IPriceFeedLegacy} from "./redstone-finance_on-chain-relayer_contracts_price-feeds_interfaces_IPriceFeedLegacy.sol";

/**
 * @title Complete price feed interface
 * @author The Redstone Oracles team
 * @dev All required public functions that must be implemented
 * by each Redstone PriceFeed contract
 */
interface IPriceFeed is IPriceFeedLegacy, AggregatorV3Interface {
  /**
   * @notice Returns data feed identifier for the PriceFeed contract
   * @return dataFeedId The identifier of the data feed
   */
  function getDataFeedId() external view returns (bytes32);
}