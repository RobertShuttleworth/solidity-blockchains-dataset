// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface LexErrors {
  enum CapType {
    NONE, // 0
    MIN_OPEN_FEE, // 1
    MAX_POS_SIZE_PAIR, // 2
    MAX_POS_SIZE_GROUP, // 3
    MAX_LEVERAGE, // 4
    MIN_LEVERAGE, // 5
    MAX_VIRTUAL_UTILIZATION, // 6
    MAX_OPEN_INTEREST, // 7
    MAX_ABS_SKEW, // 8
    MAX_BORROW_PAIR, // 9
    MAX_BORROW_GROUP, // 10
    MIN_DEPOSIT_AMOUNT, // 11
    MAX_ACCUMULATED_GAINS, // 12
    BORROW_RATE_MAX, // 13
    FUNDING_RATE_MAX, // 14
    MAX_POTENTIAL_GAIN, // 15
    MAX_TOTAL_BORROW, // 16
    MIN_PERFORMANCE_FEE // 17
    //...
  }
  error CapError(CapType, uint256 value);
}