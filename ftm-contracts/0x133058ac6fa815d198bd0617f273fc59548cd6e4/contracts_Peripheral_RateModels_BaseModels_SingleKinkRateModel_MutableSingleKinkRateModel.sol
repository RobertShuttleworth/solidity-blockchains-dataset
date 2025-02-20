// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_Peripheral_RateModels_BaseModels_SingleKinkRateModel_BaseSingleKinkRateModel.sol";

/**
 * @title MutableSingleKinkRateModel
 * @dev Single kink rate model with the ability to change rate parameters
 */
contract MutableSingleKinkRateModel is Ownable, BaseSingleKinkRateModel {
  constructor(address _initialOwner) Ownable(_initialOwner) {}

  function setRateParams(
    uint256 _baseRate,
    uint256 _multiplier,
    uint256 _kink,
    uint256 _postKinkMultiplier
  ) external onlyOwner {
    setRateParamsInternal(_baseRate, _multiplier, _kink, _postKinkMultiplier);
  }
}