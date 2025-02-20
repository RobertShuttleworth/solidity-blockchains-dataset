// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface TradingEnumsV1 {
  enum PositionPhase {
    NONE,
    OPEN_MARKET,
    OPEN_LIMIT,
    OPENED,
    CLOSE_MARKET,
    CLOSED
  }

  enum OpenOrderType {
    NONE,
    MARKET,
    LIMIT
  }
  enum CloseOrderType {
    NONE,
    MARKET
  }
  enum FeeType {
    NONE,
    OPEN_FEE,
    CLOSE_FEE,
    TRIGGER_FEE
  }
  enum LimitTrigger {
    NONE,
    TP,
    SL,
    LIQ
  }
  enum PositionField {
    NONE,
    TP,
    SL
  }

  enum PositionCloseType {
    NONE,
    TP,
    SL,
    LIQ,
    MARKET
  }
}