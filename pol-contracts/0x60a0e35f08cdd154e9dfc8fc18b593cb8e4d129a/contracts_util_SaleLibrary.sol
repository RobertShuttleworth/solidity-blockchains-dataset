// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library SaleLibrary {
  function calcAllocInUsd(
    uint256 _staked,
    uint256 _totalStaked,
    uint256 _targetUsdRaised
  ) internal pure returns (uint256) {
    return (_staked * _targetUsdRaised) / _totalStaked;
  }

  function calcAmountAnyDecimal(
    uint256 _amount,
    uint256 _srcDecimal,
    uint256 _dstDecimal
  ) internal pure returns (uint256) {
    return (_amount * (10 ** _dstDecimal)) / 10 ** _srcDecimal;
  }

  function calcAmountPercentageAnyDecimal(
    uint256 _amount,
    uint256 _percentage,
    uint256 _decimal
  ) internal pure returns (uint256) {
    return (_amount * _percentage) / (100 ** _decimal);
  }

  function calcTokenReceived(uint256 _usdPaid, uint256 _usdPrice) internal pure returns (uint256) {
    return (_usdPaid * 1e18) / _usdPrice;
  }
}