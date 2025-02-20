// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import {SynthetixPerpsV2MarketAssetGuard} from "./contracts_guards_assetGuards_SynthetixPerpsV2MarketAssetGuard.sol";
import {IHasGuardInfo} from "./contracts_interfaces_IHasGuardInfo.sol";

library SwapperV2SynthetixHelpers {
  function synthetixPerpsV2Helper(address _asset, address _poolFactory) internal view returns (address sUSDAddress) {
    sUSDAddress = SynthetixPerpsV2MarketAssetGuard(IHasGuardInfo(_poolFactory).getAssetGuard(_asset)).susdProxy();
  }
}