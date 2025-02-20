// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {ICompoundV3Comet} from "./contracts_interfaces_compound_ICompoundV3Comet.sol";
import {IEasySwapperV2} from "./contracts_swappers_easySwapperV2_interfaces_IEasySwapperV2.sol";
import {IWithdrawalVault} from "./contracts_swappers_easySwapperV2_interfaces_IWithdrawalVault.sol";

library SwapperV2Helpers {
  function getUnrolledAssets(address _asset, address _dHedgeVault) internal view returns (address[] memory assets) {
    IWithdrawalVault.TrackedAsset[] memory trackedAssets = IEasySwapperV2(_asset).getTrackedAssets(_dHedgeVault);
    uint256 assetsLength = trackedAssets.length;
    assets = new address[](assetsLength);

    for (uint256 i; i < assetsLength; ++i) {
      assets[i] = trackedAssets[i].token;
    }
  }

  /// @dev It's possible to disable base token of CompoundV3Comet asset, while having positive balance of it,
  ///      hence this helper is required for WithdrawalVault to pick base token after withdrawing from CompoundV3Comet asset
  function getCompoundV3BaseAsset(address _compoundV3CometAsset) internal view returns (address baseAsset) {
    baseAsset = ICompoundV3Comet(_compoundV3CometAsset).baseToken();
  }
}