// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IContractRegistryBase {
  function isImplementationValidForProxy(
    bytes32 proxyNameHash,
    address _implementation
  ) external view returns (bool);
}