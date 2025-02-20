// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface ITradeIncentivizerV1 {
  function informTradeOpen(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 openFee
  ) external;

  function informTradeClose(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 closeFee,
    int256 profitPrecision,
    uint256 finalValue
  ) external;
}