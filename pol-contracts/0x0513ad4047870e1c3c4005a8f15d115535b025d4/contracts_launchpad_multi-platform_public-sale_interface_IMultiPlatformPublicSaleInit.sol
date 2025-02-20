// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

interface IMultiPlatformPublicSaleInit {
  function init(
    uint128 _startInEpoch,
    uint128 _durationPerBoosterInSeconds,
    uint256 _targetUsdRaised,
    uint256[] calldata _platformPercentage_d2,
    uint256 _tokenPriceInUsdDecimal,
    uint256[4] calldata _feePercentage_d2,
    address _usdPaymentToken,
    string[3] calldata _nameVersionMsg
  ) external;
}