// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IRateModelV1 {
  /**
   * @param x The x value, between 0-1. scaled by PRECISION
   */
  function getRate(uint256 x) external view returns (uint256);
}