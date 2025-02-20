// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IOracle {
  struct Price {
    uint256 price;
    uint256 timestamp;
    uint8 decimals;
  }

  error InvalidArrayLengthERR();

  function getPrice(bytes32 id) external view returns (Price memory);
}