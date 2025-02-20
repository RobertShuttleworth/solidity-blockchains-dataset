// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_AdministrationContracts_AcceptableImplementationClaimableAdmin.sol";
import "./contracts_AdministrationContracts_IContractRegistryBase.sol";

/**
 * @title AcceptableRegistryImplementationClaimableAdmin
 */
contract AcceptableRegistryImplementationClaimableAdmin is
  AcceptableImplementationClaimableAdmin,
  AcceptableRegistryImplementationClaimableAdminStorage
{
  bytes32 public immutable CONTRACT_NAME_HASH;

  constructor(address _registry, string memory proxyName) {
    registry = _registry;
    CONTRACT_NAME_HASH = keccak256(abi.encodePacked(proxyName));
  }

  function approvePendingImplementationInternal(
    address _implementation
  ) internal view override returns (bool) {
    return
      IContractRegistryBase(registry).isImplementationValidForProxy(
        CONTRACT_NAME_HASH,
        _implementation
      );
  }
}