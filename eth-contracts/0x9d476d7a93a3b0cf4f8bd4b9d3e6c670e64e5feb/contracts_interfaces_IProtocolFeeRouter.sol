// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './contracts_interfaces_IProtocolFees.sol';

interface IProtocolFeeRouter {
  function protocolFees() external view returns (IProtocolFees);
}