// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IAffiliationV1 {
  event PositionRequested(
    bytes32 indexed domain,
    bytes32 indexed referralCode,
    bytes32 indexed positionId
  );
  event LiquidityProvided(
    bytes32 indexed domain,
    bytes32 indexed referralCode,
    address indexed user,
    uint amountUnderlying,
    uint processingEpoch
  );
}