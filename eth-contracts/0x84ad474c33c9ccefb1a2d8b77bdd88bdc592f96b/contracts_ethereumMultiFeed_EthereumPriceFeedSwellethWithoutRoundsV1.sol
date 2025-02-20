// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {PriceFeedWithoutRoundsForMultiFeedAdapter} from "./redstone-finance_on-chain-relayer_contracts_price-feeds_without-rounds_PriceFeedWithoutRoundsForMultiFeedAdapter.sol";
import {IRedstoneAdapter} from "./redstone-finance_on-chain-relayer_contracts_core_IRedstoneAdapter.sol";

contract EthereumPriceFeedSwellethWithoutRoundsV1 is PriceFeedWithoutRoundsForMultiFeedAdapter {
  function description() public view virtual override returns (string memory) {
    return "RedStone Price Feed for SWELL/ETH";
  }

  function getDataFeedId() public view virtual override returns (bytes32) {
    return bytes32("SWELL/ETH");
  }

  function getPriceFeedAdapter() public view virtual override returns (IRedstoneAdapter) {
    return IRedstoneAdapter(0xd72a6BA4a87DDB33e801b3f1c7750b2d0911fC6C);
  }
}