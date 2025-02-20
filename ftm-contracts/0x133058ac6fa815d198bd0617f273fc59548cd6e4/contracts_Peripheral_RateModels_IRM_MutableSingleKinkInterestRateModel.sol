// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_interfaces_IInterestRateModel.sol";
import "./contracts_Peripheral_RateModels_BaseModels_SingleKinkRateModel_MutableSingleKinkRateModel.sol";

/**
 * @title MutableSingleKinkInterestRateModel
 * @dev Single kink rate model for interest rates with the ability to change rate parameters
 */
contract MutableSingleKinkInterestRateModel is
  MutableSingleKinkRateModel,
  IInterestRateModel
{
  constructor() MutableSingleKinkRateModel(msg.sender) {}

  function getBorrowRate(
    uint256 utilization
  ) external view override returns (uint256) {
    return getRateInternal(utilization);
  }
}