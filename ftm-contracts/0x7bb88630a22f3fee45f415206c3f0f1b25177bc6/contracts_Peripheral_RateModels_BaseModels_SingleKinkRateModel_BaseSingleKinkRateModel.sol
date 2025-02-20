// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IRateModelV1} from "./contracts_Lynx_interfaces_IRateModelV1.sol";

/**
 * @title BaseSingleKinkRateModel
 * @dev Base contract for single kink rate models
 */
contract BaseSingleKinkRateModel is IRateModelV1 {
  uint public constant PRECISION = 1e18;

  /**
   * @notice The base rate which is the y-intercept when X = 0
   */
  uint256 public baseRate;

  /**
   * @notice The multiplier of utilization rate that gives the slope of the rate
   */
  uint256 public multiplier;

  /**
   * @notice The point at which the 'postKinkMultiplier' is applied
   */
  uint256 public kink;

  /**
   * @notice The multiplier when X > kink
   */
  uint256 public postKinkMultiplier;

  /**
   * @notice The rate when X = kink
   * @dev Saves gas on reading storage variables
   */
  uint256 public rateOnKink;

  event NewRateParams(
    uint256 baseRate,
    uint256 multiplier,
    uint256 kink,
    uint256 postKinkMultiplier,
    uint256 rateOnKink
  );

  function getRate(uint256 x) external view returns (uint256) {
    return getRateInternal(x);
  }

  function setRateParamsInternal(
    uint256 _baseRate,
    uint256 _multiplier,
    uint256 _kink,
    uint256 _postKinkMultiplier
  ) internal {
    // Sanity, kink cannot be higher than 100%
    require(_kink <= PRECISION, "KINK_TOO_HIGH");

    // Set rate params
    baseRate = _baseRate;
    multiplier = _multiplier;
    kink = _kink;
    postKinkMultiplier = _postKinkMultiplier;

    // Calculate rateOnKink
    rateOnKink = (kink * multiplier) / PRECISION + baseRate;

    // Event
    emit NewRateParams(
      _baseRate,
      _multiplier,
      _kink,
      _postKinkMultiplier,
      rateOnKink
    );
  }

  function getRateInternal(uint256 x) internal view returns (uint256) {
    uint256 safeX = x > PRECISION ? PRECISION : x;
    uint256 _kink = kink;

    if (x <= _kink) {
      return (x * multiplier) / PRECISION + baseRate;
    } else {
      uint excess = safeX - _kink;
      return (excess * postKinkMultiplier) / PRECISION + rateOnKink;
    }
  }
}