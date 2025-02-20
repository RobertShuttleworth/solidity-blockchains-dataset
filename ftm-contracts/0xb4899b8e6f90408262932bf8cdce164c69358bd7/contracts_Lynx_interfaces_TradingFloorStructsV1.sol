// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_interfaces_TradingEnumsV1.sol";

interface TradingFloorStructsV1 is TradingEnumsV1 {
  enum AdminNumericParam {
    NONE,
    MAX_TRADES_PER_PAIR,
    MAX_SL_F,
    MAX_SANITY_PROFIT_F
  }

  /**
   * @dev Memory struct for identifiers
   */
  struct PositionRequestIdentifiers {
    address trader;
    uint16 pairId;
    address settlementAsset;
    uint32 positionIndex;
  }

  struct PositionRequestParams {
    bool long;
    uint256 collateral; // Settlement Asset Decimals
    uint32 leverage;
    uint64 minPrice; // PRICE_SCALE
    uint64 maxPrice; // PRICE_SCALE
    uint64 tp; // PRICE_SCALE
    uint64 sl; // PRICE_SCALE
    uint64 tpByFraction; // FRACTION_SCALE
    uint64 slByFraction; // FRACTION_SCALE
  }

  /**
   * @dev Storage struct for identifiers
   */
  struct PositionIdentifiers {
    // Slot 0
    address settlementAsset; // 20 bytes
    uint16 pairId; // 02 bytes
    uint32 index; // 04 bytes
    // Slot 1
    address trader; // 20 bytes
  }

  struct Position {
    // Slot 0
    uint collateral; // 32 bytes -- Settlement Asset Decimals
    // Slot 1
    PositionPhase phase; // 01 bytes
    uint64 inPhaseSince; // 08 bytes
    uint32 leverage; // 04 bytes
    bool long; // 01 bytes
    uint64 openPrice; // 08 bytes -- PRICE_SCALE (8)
    uint32 spreadReductionF; // 04 bytes -- FRACTION_SCALE (5)
  }

  /**
   * Holds the non liquidation limits for the position
   */
  struct PositionLimitsInfo {
    uint64 tpLastUpdated; // 08 bytes -- timestamp
    uint64 slLastUpdated; // 08 bytes -- timestamp
    uint64 tp; // 08 bytes -- PRICE_SCALE (8)
    uint64 sl; // 08 bytes -- PRICE_SCALE (8)
  }

  /**
   * Holds the prices for opening (and market closing) of a position
   */
  struct PositionTriggerPrices {
    uint64 minPrice; // 08 bytes -- PRICE_SCALE
    uint64 maxPrice; // 08 bytes -- PRICE_SCALE
    uint64 tpByFraction; // 04 bytes -- FRACTION_SCALE
    uint64 slByFraction; // 04 bytes -- FRACTION_SCALE
  }

  /**
   * @dev administration struct, used to keep tracks on the 'PairTraders' list and
   *      to limit the amount of positions a trader can have
   */
  struct PairTraderInfo {
    uint32 positionsCounter; // 04 bytes
    uint32 positionInArray; // 04 bytes (the index + 1)
    // Note : Can add more fields here
  }
}