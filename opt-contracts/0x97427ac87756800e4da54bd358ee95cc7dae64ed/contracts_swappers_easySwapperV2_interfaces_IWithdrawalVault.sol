// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {ISwapper} from "./contracts_interfaces_flatMoney_swapper_ISwapper.sol";

interface IWithdrawalVault {
  struct MultiInSingleOutData {
    ISwapper.SrcTokenSwapDetails[] srcData;
    ISwapper.DestData destData;
  }

  struct TrackedAsset {
    address token;
    uint256 balance;
  }

  function recoverAssets() external;

  function recoverAssets(uint256 _portion, address _to) external;

  function swapToSingleAsset(MultiInSingleOutData calldata _swapData, uint256 _expectedDestTokenAmount) external;

  function unrollAssets(address _dHedgeVault, uint256 _slippageTolerance) external;

  function getTrackedAssets() external view returns (TrackedAsset[] memory trackedAssets);
}