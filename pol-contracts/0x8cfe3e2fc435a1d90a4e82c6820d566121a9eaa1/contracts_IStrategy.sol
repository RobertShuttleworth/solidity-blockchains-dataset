// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStrategy {
  function strategyRepay(
    uint256 _total,
    uint256 _providerID,
    uint256 _loanId
  ) external;

  function cancelStrategy(uint256 _providerID, uint256 _loanID) external;
}