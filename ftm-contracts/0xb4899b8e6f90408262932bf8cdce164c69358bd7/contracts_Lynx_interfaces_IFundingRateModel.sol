// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IFundingRateModel {
  // return value is the "funding paid by heavier side" in PRECISION per OI (heavier side) per second
  // e.g : (0.01 * PRECISION) = Paying (heavier) side (as a whole) pays 1% of funding per second for each OI unit
  function getFundingRate(
    uint256 pairId,
    uint256 openInterestLong,
    uint256 openInterestShort,
    uint256 pairMaxOpenInterest
  ) external view returns (uint256);
}