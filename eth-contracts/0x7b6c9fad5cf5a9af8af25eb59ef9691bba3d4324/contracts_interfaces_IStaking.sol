// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IStaking {
  function depositByPresale(address user_, uint256 amount_) external;
}