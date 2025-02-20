// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {PriceFeedWithoutRoundsForMultiFeedAdapter} from "./redstone-finance_on-chain-relayer_contracts_price-feeds_without-rounds_PriceFeedWithoutRoundsForMultiFeedAdapter.sol";
import {IRedstoneAdapter} from "./redstone-finance_on-chain-relayer_contracts_core_IRedstoneAdapter.sol";

contract ArbitrumOnePriceFeedSusdxArbFundamentalWithoutRoundsV1 is PriceFeedWithoutRoundsForMultiFeedAdapter {
  function description() public view virtual override returns (string memory) {
    return "RedStone Price Feed for sUSDX_ARB_FUNDAMENTAL";
  }

  function getDataFeedId() public view virtual override returns (bytes32) {
    return bytes32("sUSDX_ARB_FUNDAMENTAL");
  }

  function getPriceFeedAdapter() public view virtual override returns (IRedstoneAdapter) {
    return IRedstoneAdapter(0x89e60b56efD70a1D4FBBaE947bC33cae41e37A72);
  }
}