// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface ISaleGateway {
  function allDstChainsSupportedLength() external view returns (uint256);

  function allDstChains(uint256) external view returns (uint240 chainID, uint16 lzChainID, address saleGateway);

  function dstChainIndex(uint240) external view returns (uint256);
}