// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IInterestRateModel {
  // Returns asset/second of interest per borrowed unit
  // e.g : (0.01 * PRECISION) = 1% of interest per second
  function getBorrowRate(uint256 utilization) external view returns (uint256);
}