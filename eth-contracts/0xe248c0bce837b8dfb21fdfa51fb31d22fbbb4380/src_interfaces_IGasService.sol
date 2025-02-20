// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGasService {
  function adjustSubsidizedExecutionFeeValue(int256 deltaValueE30) external;

  function subsidizedExecutionFeeValue() external view returns (uint256);
}