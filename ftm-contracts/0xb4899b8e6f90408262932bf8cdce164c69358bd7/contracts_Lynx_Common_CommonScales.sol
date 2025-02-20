// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/**
 * @dev only use immutables and constants in this contract
 */
contract CommonScales {
  uint256 public constant PRECISION = 1e18; // 18 decimals

  uint256 public constant LEVERAGE_SCALE = 100; // 2 decimal points

  uint256 public constant FRACTION_SCALE = 100000; // 5 decimal points

  uint256 public constant ACCURACY_IMPROVEMENT_SCALE = 1e9;

  function calculateLeveragedPosition(
    uint256 collateral,
    uint256 leverage
  ) internal pure returns (uint256) {
    return (collateral * leverage) / LEVERAGE_SCALE;
  }
}