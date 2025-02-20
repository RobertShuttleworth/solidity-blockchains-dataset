// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

interface IMultiPlatformPublicSale {
  function buyToken(uint240 _chainID, uint256 _amountIn, address _user) external;
}