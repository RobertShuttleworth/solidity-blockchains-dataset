// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_interfaces_IFundingRateModel.sol";
import "./contracts_Peripheral_RateModels_BaseModels_SingleKinkRateModel_MutableSingleKinkRateModel.sol";

/**
 * @title MutableSingleKinkFundingRateModel
 * @dev Single kink rate model for funding rates with the ability to change rate parameters
 */
contract MutableSingleKinkFundingRateModel is
  MutableSingleKinkRateModel,
  IFundingRateModel
{
  constructor() MutableSingleKinkRateModel(msg.sender) {}

  // return values in mantissa per oi unit per second
  function getFundingRate(
    uint256, // pairId,
    uint256 openInterestLong,
    uint256 openInterestShort,
    uint256 // pairMaxOpenInterest
  ) external view override returns (uint256) {
    uint256 absDIff = openInterestLong > openInterestShort
      ? openInterestLong - openInterestShort
      : openInterestShort - openInterestLong;

    uint sum = openInterestLong + openInterestShort;

    if (sum == 0) {
      return 0;
    } else {
      return getRateInternal((absDIff * PRECISION) / sum);
    }
  }
}