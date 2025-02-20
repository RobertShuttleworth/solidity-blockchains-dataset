// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

contract Constants {
  bytes32 public constant   ALLOWED_ROLE = keccak256("ALLOWED_ROLE");
  uint256 internal constant DECIMALS = 18;
  uint256 internal constant NUMERATOR = 10 ** DECIMALS;
  uint256 internal constant defaultThreshold = 172800;
}